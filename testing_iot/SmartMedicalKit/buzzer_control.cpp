//buzzer_control.cpp
#include "buzzer_control.h"

// 确认你的线插在 D23
const int buzzerPin = 23; 

void setupBuzzer() {
  pinMode(buzzerPin, OUTPUT);
  // 确保初始状态没有声音
  noTone(buzzerPin); 
}

void handleBuzzerOn() {
  Serial.println("Buzzer turned ON");
  // 产生 1000Hz 的频率让无源蜂鸣器发声
  tone(buzzerPin, 1000); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS ON");
}

void handleBuzzerOff() {
  Serial.println("Buzzer turned OFF");
  // 停止发声
  noTone(buzzerPin); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS OFF");
}