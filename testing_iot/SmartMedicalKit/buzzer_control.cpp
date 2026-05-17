// buzzer_control.cpp
#include "buzzer_control.h"

// Pin is 2, matching your (S) connected to D2
const int buzzerPin = 19; 

void setupBuzzer() {
  pinMode(buzzerPin, OUTPUT);
  // Keep it OFF at startup. For a 3-pin module, LOW = OFF
  digitalWrite(buzzerPin, LOW); 
}

void handleBuzzerOn() {
  Serial.println("Buzzer turned ON (Active-High Trigger)");
  // Pull HIGH to send a signal to the 'S' pin and make it sound
  digitalWrite(buzzerPin, HIGH); 
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS ON");
}

void triggerBuzzerHardware(bool turnOn) {
  // If turnOn is true, pull HIGH. If false, pull LOW.
  digitalWrite(buzzerPin, turnOn ? HIGH : LOW);
}

void handleBuzzerOff() {
  Serial.println("Buzzer turned OFF (Active-High Trigger inactive)");
  // Pull LOW to cut the signal to the 'S' pin and turn it off
  digitalWrite(buzzerPin, LOW); 
  
  // 修复了这里的拼写错误：把 }rver 改回 server
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS OFF");
}