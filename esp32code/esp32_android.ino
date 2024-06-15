#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoBLE.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// BLE 서비스와 특성 정의
BLEService musicService("3db02924-b2a6-4d47-be1f-0f90ad62a048");
BLECharacteristic musicCharacteristic("8d8218b6-97bc-4527-a8db-13094ac06b1d", BLERead | BLEWrite, 512);

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
  Serial.println("Display initialized");

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
}

void loop()
{
  handleBLE();
}