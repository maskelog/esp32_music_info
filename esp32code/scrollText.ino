void scrollTextTask(void *pvParameters)
{
  while (1)
  {
    // 텍스트의 너비를 계산
    int textWidth = getTextWidth(currentMusicInfo.c_str());

    if (textWidth > SCREEN_WIDTH)
    {
      // 텍스트가 화면 너비를 초과하는 경우 스크롤
      int startX = SCREEN_WIDTH;
      int endX = -textWidth;

      while (startX > endX)
      {
        display.clearDisplay();
        EURK_setxy(startX, 0);                                   // 출력할 문자(혹은 문자열)의 좌표 설정
        EURK_puts(const_cast<char *>(currentMusicInfo.c_str())); // 화면에 문자열 출력
        display.display();
        startX -= 2; // 이동 속도 조절
        delay(SCROLL_DELAY);
      }
    }
    else
    {
      // 텍스트가 화면 너비를 초과하지 않는 경우 중앙 정렬하여 출력
      display.clearDisplay();
      EURK_setxy((SCREEN_WIDTH - textWidth) / 2, 0);
      EURK_puts(const_cast<char *>(currentMusicInfo.c_str()));
      display.display();
      delay(SCROLL_DELAY);
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