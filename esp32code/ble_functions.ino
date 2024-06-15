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
        currentMusicInfo = String(musicInfo);

        Serial.print("Received music info: ");
        Serial.println(musicInfo);
      }
      delay(100); // Add a small delay to avoid flooding the loop
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}