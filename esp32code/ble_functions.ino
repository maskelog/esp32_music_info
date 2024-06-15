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

        // Display the music info on the OLED using EURK
        display.clearDisplay();
        EURK_setxy(0, 0);     // 출력할 문자(혹은 문자열)의 좌표 설정
        EURK_puts(musicInfo); // 화면에 문자열 출력
        display.display();

        Serial.print("Received music info: ");
        Serial.println(musicInfo);
      }
      delay(100); // Add a small delay to avoid flooding the loop
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}