// buzzer_control.cpp
#include "buzzer_control.h"

const int buzzerPin = 23; 

void setupBuzzer() {
  pinMode(buzzerPin, OUTPUT);      // 第一步：激活引脚
  digitalWrite(buzzerPin, HIGH);   // 第二步：给高电平，让它闭嘴
}

void handleBuzzerOn() {
  Serial.println("Buzzer turned ON (Testing Low-Level)");
  // ⚠️ 尝试给 LOW，看低电平触发能否让它响
  digitalWrite(buzzerPin, LOW); 
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS ON");
}

void handleBuzzerOff() {
  Serial.println("Buzzer turned OFF (Testing Low-Level)");
  // ⚠️ 尝试给 HIGH 让它停止
  digitalWrite(buzzerPin, HIGH); 
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS OFF");
}