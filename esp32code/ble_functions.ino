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

        Serial.print("Received music info: ");
        Serial.println(musicInfo);
      }
      delay(100); // Add a small delay to avoid flooding the loop
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
