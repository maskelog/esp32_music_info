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
#define SCROLL_DELAY 50
#define INACTIVITY_TIMEOUT 30000

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

BLEService musicService("3db02924-b2a6-4d47-be1f-0f90ad62a048");
BLECharacteristic musicCharacteristic("8d8218b6-97bc-4527-a8db-13094ac06b1d", BLERead | BLEWrite, 512);
BLECharacteristic timeCharacteristic("a1b2c3d4-e5f6-7a8b-9c0d-ef0123456789", BLERead | BLEWrite, 512);

String currentMusicInfo = "";
String currentTitle = "";
String currentArtist = "";
String currentTime = "00:00";
int scrollPosition = 0;
TaskHandle_t scrollTaskHandle;
unsigned long lastUpdate = 0;
bool displayActive = true;
bool needsRedraw = true;

void setup()
{
  Serial.begin(115200);
  Serial.println("Starting setup...");

  delay(2000);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C))
  {
    Serial.println(F("SSD1306 allocation failed"));
    while (1)
      ;
  }
  display.display();
  delay(2000);
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  Serial.println("Display initialized");

  EURK_hancode(HANCODE_UTF_8);

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
  musicService.addCharacteristic(timeCharacteristic);
  BLE.addService(musicService);

  musicCharacteristic.writeValue("Waiting for music...");
  BLE.advertise();

  Serial.println("Bluetooth device active, waiting for connections...");

  xTaskCreate(scrollTextTask, "ScrollTextTask", 4096, NULL, 1, &scrollTaskHandle);
}

void loop()
{
  handleBLE();

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
        const uint8_t *value = musicCharacteristic.value();
        size_t length = musicCharacteristic.valueLength();

        char musicInfo[length + 1];
        memcpy(musicInfo, value, length);
        musicInfo[length] = '\0';

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
          lastUpdate = millis();

          if (!displayActive)
          {
            display.ssd1306_command(SSD1306_DISPLAYON);
            displayActive = true;
            Serial.println("Display turned on due to new music info");
          }

          Serial.print("Received new music info: ");
          Serial.println(musicInfo);

          updateDisplay();
        }
      }

      if (timeCharacteristic.written())
      {
        const uint8_t *value = timeCharacteristic.value();
        size_t length = timeCharacteristic.valueLength();

        char timeInfo[length + 1];
        memcpy(timeInfo, value, length);
        timeInfo[length] = '\0';

        currentTime = String(timeInfo);
        updateDisplay();
      }
      delay(100);
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}

void updateDisplay()
{
  display.clearDisplay();
  display.setTextSize(1);

  EURK_setxy(0, 0);
  EURK_puts(const_cast<char *>(currentArtist.c_str()));

  if (getTextWidth(currentTitle.c_str()) > SCREEN_WIDTH)
  {
    scrollPosition = SCREEN_WIDTH;
  }
  else
  {
    scrollPosition = 0;
    needsRedraw = true;
  }

  EURK_setxy(0, 24);
  EURK_puts(const_cast<char *>(currentTime.c_str()));

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
        scrollPosition -= 4;
        if (scrollPosition < -titleWidth)
        {
          scrollPosition = SCREEN_WIDTH;
        }

        display.clearDisplay();
        EURK_setxy(0, 0);
        EURK_puts(const_cast<char *>(currentArtist.c_str()));
        EURK_setxy(scrollPosition, 16);
        EURK_puts(const_cast<char *>(currentTitle.c_str()));
        EURK_setxy(0, 24);
        EURK_puts(const_cast<char *>(currentTime.c_str()));
        display.display();
      }
      else
      {
        if (needsRedraw)
        {
          display.clearDisplay();
          EURK_setxy(0, 0);
          EURK_puts(const_cast<char *>(currentArtist.c_str()));
          EURK_setxy(0, 16);
          EURK_puts(const_cast<char *>(currentTitle.c_str()));
          EURK_setxy(0, 24);
          EURK_puts(const_cast<char *>(currentTime.c_str()));
          display.display();
          needsRedraw = false;
        }
      }
    }
    vTaskDelay(SCROLL_DELAY / portTICK_PERIOD_MS);
  }
}

int getTextWidth(const char *text)
{
  int width = 0;
  while (*text)
  {
    width += 6;
    text++;
  }
  return width;
}