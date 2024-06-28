#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoBLE.h>
#include <EURK_Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
#define SCROLL_DELAY 50          // 슬라이드 딜레이를 줄여 배터리 절약
#define INACTIVITY_TIMEOUT 30000 // 30초 동안 비활성 시 디스플레이 끔

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// BLE 서비스와 특성 정의
BLEService musicService("3db02924-b2a6-4d47-be1f-0f90ad62a048");
BLECharacteristic musicCharacteristic("8d8218b6-97bc-4527-a8db-13094ac06b1d", BLERead | BLEWrite, 512);

String currentMusicInfo = "";
String currentTitle = "";
String currentArtist = "";
int scrollPosition = 0;
TaskHandle_t scrollTaskHandle;
unsigned long lastUpdate = 0;
bool displayActive = true;
bool needsRedraw = true;

void setup()
{
  Serial.begin(115200);
  Serial.println("Starting setup...");

  // 디스플레이 초기화
  delay(2000); // 추가된 지연 시간
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C))
  {
    Serial.println(F("SSD1306 allocation failed"));
    while (1)
      ;
  }
  display.display();
  delay(2000); // 초기화 완료 후 지연 시간 추가
  display.clearDisplay();
  display.setTextSize(1); // 텍스트 사이즈를 줄임
  display.setTextColor(WHITE);
  Serial.println("Display initialized");

  // EURK 초기화
  EURK_hancode(HANCODE_UTF_8); // 한글 코드 설정 (UTF-8)

  // BLE 초기화
  if (!BLE.begin())
  {
    Serial.println("starting BLE failed!");
    while (1)
      ;
  }
  Serial.println("BLE initialized");

  BLE.setLocalName("ESP32_Music_Display");
  BLE.setAdvertisedService(musicService);
  musicService.addCharacteristic(musicCharacteristic);
  BLE.addService(musicService);

  musicCharacteristic.writeValue("Waiting for music...");
  BLE.advertise();

  Serial.println("Bluetooth device active, waiting for connections...");

  // 스크롤 텍스트를 위한 태스크 생성
  xTaskCreate(scrollTextTask, "ScrollTextTask", 4096, NULL, 1, &scrollTaskHandle);
}

void loop()
{
  handleBLE();

  // 비활성 시간 확인
  if (millis() - lastUpdate > INACTIVITY_TIMEOUT && displayActive)
  {
    display.ssd1306_command(SSD1306_DISPLAYOFF);
    displayActive = false;
    Serial.println("Display turned off due to inactivity");
  }
}

void handleBLE()
{
  BLEDevice central = BLE.central();

  if (central)
  {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected())
    {
      if (musicCharacteristic.written())
      {
        // Get the value as a byte array
        const uint8_t *value = musicCharacteristic.value();
        size_t length = musicCharacteristic.valueLength();

        // Convert the byte array to a null-terminated char array
        char musicInfo[length + 1];
        memcpy(musicInfo, value, length);
        musicInfo[length] = '\0'; // Null-terminate the char array

        // 현재 음악 정보를 업데이트
        String newMusicInfo = String(musicInfo);
        if (newMusicInfo != currentMusicInfo)
        {
          currentMusicInfo = newMusicInfo;
          int delimiterIndex = currentMusicInfo.indexOf(" - ");
          if (delimiterIndex != -1)
          {
            currentTitle = currentMusicInfo.substring(0, delimiterIndex);
            currentArtist = currentMusicInfo.substring(delimiterIndex + 3);
          }
          else
          {
            currentTitle = currentMusicInfo;
            currentArtist = "";
          }
          lastUpdate = millis(); // 마지막 업데이트 시간 갱신

          // 디스플레이가 꺼져있다면 켬
          if (!displayActive)
          {
            display.ssd1306_command(SSD1306_DISPLAYON);
            displayActive = true;
            Serial.println("Display turned on due to new music info");
          }

          Serial.print("Received new music info: ");
          Serial.println(musicInfo);

          // 새 음악 정보가 수신되면 디스플레이 업데이트
          updateDisplay();
        }
      }
      delay(100); // Add a small delay to avoid flooding the loop
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}

void updateDisplay()
{
  display.clearDisplay();
  display.setTextSize(1); // 텍스트 사이즈를 줄임

  // 가수 정보 출력
  EURK_setxy(0, 0);
  EURK_puts(const_cast<char *>(currentArtist.c_str())); // (0, 0)에 가수 출력

  // 제목이 길 경우 스크롤을 위해 초기 위치 설정
  if (getTextWidth(currentTitle.c_str()) > SCREEN_WIDTH)
  {
    scrollPosition = SCREEN_WIDTH;
  }
  else
  {
    scrollPosition = 0;
    needsRedraw = true;
  }

  display.display();
}

void scrollTextTask(void *pvParameters)
{
  while (1)
  {
    if (displayActive)
    {
      int titleWidth = getTextWidth(currentTitle.c_str());
      if (titleWidth > SCREEN_WIDTH)
      {
        scrollPosition -= 4; // 스크롤 속도 증가
        if (scrollPosition < -titleWidth)
        {
          scrollPosition = SCREEN_WIDTH;
        }

        // 제목 스크롤
        display.clearDisplay();
        EURK_setxy(0, 0);
        EURK_puts(const_cast<char *>(currentArtist.c_str())); // 가수 출력 (0, 0)
        EURK_setxy(scrollPosition, 16);
        EURK_puts(const_cast<char *>(currentTitle.c_str())); // 제목 출력 (스크롤 위치에 따라)
        display.display();
      }
      else
      {
        // 제목이 화면 안에 들어오는 경우 고정
        if (needsRedraw)
        {
          display.clearDisplay();
          EURK_setxy(0, 0);
          EURK_puts(const_cast<char *>(currentArtist.c_str())); // 가수 출력 (0, 0)
          EURK_setxy(0, 16);
          EURK_puts(const_cast<char *>(currentTitle.c_str())); // 제목 출력 (0, 16)
          display.display();
          needsRedraw = false;
        }
      }
    }
    vTaskDelay(SCROLL_DELAY / portTICK_PERIOD_MS); // 잠시 대기하여 다른 태스크가 실행될 수 있도록 함
  }
}

int getTextWidth(const char *text)
{
  int width = 0;
  while (*text)
  {
    // 각 글자의 너비를 계산하여 더함
    width += 6; // 각 글자의 너비 (필요에 따라 조정)
    text++;
  }
  return width;
}
