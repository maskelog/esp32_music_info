void handleBLE() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected()) {
      if (musicCharacteristic.written()) {
        const uint8_t* value = musicCharacteristic.value();
        size_t length = musicCharacteristic.valueLength();
        char musicTitle[length + 1];
        memcpy(musicTitle, value, length);
        musicTitle[length] = '\0'; // Null-terminate the char array

        String musicTitleStr = String(musicTitle);
        Serial.print("Received music title: ");
        Serial.println(musicTitleStr);

        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 10);
        display.print("Now Playing:");
        display.setCursor(0, 20);
        display.print(musicTitleStr);
        display.display();
      }
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
