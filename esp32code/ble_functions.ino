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

        // Parse the music info
        String musicInfoStr = String(musicInfo);
        Serial.print("Received music info: ");
        Serial.println(musicInfoStr);

        // Display the music info on the OLED
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 10);
        display.print(musicInfoStr);
        display.display();
      }
      delay(100); // Add a small delay to avoid flooding the loop
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}