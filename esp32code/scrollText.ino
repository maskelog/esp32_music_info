void scrollTextTask(void *pvParameters)
{
  while (1)
  {
    if (displayActive)
    {
      // 텍스트의 너비를 계산
      int titleWidth = getTextWidth(currentTitle.c_str());
      int artistWidth = getTextWidth(currentArtist.c_str());

      if (titleWidth > SCREEN_WIDTH)
      {
        // 제목이 화면 너비를 초과하는 경우 스크롤
        int startX = SCREEN_WIDTH;
        int endX = -titleWidth;

        while (startX > endX)
        {
          display.clearDisplay();
          EURK_setxy(startX, 0);                                // 제목 출력 좌표 설정
          EURK_puts(const_cast<char *>(currentTitle.c_str()));  // 제목 출력
          EURK_setxy((SCREEN_WIDTH - artistWidth) / 2, 16);     // 가수 중앙 정렬
          EURK_puts(const_cast<char *>(currentArtist.c_str())); // 가수 출력
          display.display();
          startX -= 2; // 이동 속도 조절
          delay(SCROLL_DELAY);
        }
      }
      else if (artistWidth > SCREEN_WIDTH)
      {
        // 가수가 화면 너비를 초과하는 경우 스크롤
        int startX = SCREEN_WIDTH;
        int endX = -artistWidth;

        while (startX > endX)
        {
          display.clearDisplay();
          EURK_setxy((SCREEN_WIDTH - titleWidth) / 2, 0);       // 제목 중앙 정렬
          EURK_puts(const_cast<char *>(currentTitle.c_str()));  // 제목 출력
          EURK_setxy(startX, 16);                               // 가수 출력 좌표 설정
          EURK_puts(const_cast<char *>(currentArtist.c_str())); // 가수 출력
          display.display();
          startX -= 2; // 이동 속도 조절
          delay(SCROLL_DELAY);
        }
      }
      else
      {
        // 텍스트가 화면 너비를 초과하지 않는 경우 중앙 정렬하여 출력
        display.clearDisplay();
        EURK_setxy((SCREEN_WIDTH - titleWidth) / 2, 0);
        EURK_puts(const_cast<char *>(currentTitle.c_str()));
        EURK_setxy((SCREEN_WIDTH - artistWidth) / 2, 16);
        EURK_puts(const_cast<char *>(currentArtist.c_str()));
        display.display();
        delay(SCROLL_DELAY);
      }
    }
    vTaskDelay(100 / portTICK_PERIOD_MS); // 잠시 대기하여 다른 태스크가 실행될 수 있도록 함
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