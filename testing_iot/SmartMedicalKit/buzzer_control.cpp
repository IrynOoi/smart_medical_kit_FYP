// buzzer_control.cpp
#include "buzzer_control.h"

// Pin changed to 4 because D4 successfully drives your low-level active buzzer
const int buzzerPin = 2; 

void setupBuzzer() {
  pinMode(buzzerPin, OUTPUT);
  // Keep it OFF at startup (For low-level trigger, HIGH = OFF)
  digitalWrite(buzzerPin, HIGH); 
}

void handleBuzzerOn() {
  Serial.println("Buzzer turned ON (Low-Level Trigger active)");
  // Pull LOW to make the buzzer sound
  digitalWrite(buzzerPin, LOW); 
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS ON");
}

void handleBuzzerOff() {
  Serial.println("Buzzer turned OFF (Low-Level Trigger inactive)");
  // Pull HIGH to turn it off
  digitalWrite(buzzerPin, HIGH); 
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "BUZZER IS OFF");
}