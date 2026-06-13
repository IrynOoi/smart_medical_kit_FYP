// touch_control.cpp
#include <Arduino.h>

const int touchPin = 23;    
int lastTouchState = LOW;   
unsigned long lastDebounceTime = 0;  
const unsigned long debounceDelay = 500;

// ✅ Pull in external variables and functions from our main file
extern bool isDoseWaiting; 
void executeDispense(); 

bool checkTouch();

void setupTouch() {
  pinMode(touchPin, INPUT_PULLDOWN); 
}

void handleTouch() {
  if (checkTouch()) {
    Serial.println("👆 Touch detected!");
    
    if (isDoseWaiting) {
       // Only dispense if a dose is actually waiting!
       executeDispense();
    } else {
       Serial.println("No dose waiting right now.");
    }
  }
}

bool checkTouch() {
  int currentTouchState = digitalRead(touchPin);
  
  if (currentTouchState == HIGH) {
    delay(20); // Small delay to ignore instantaneous spikes
    if (digitalRead(touchPin) == HIGH) { // Verify it's still HIGH
      if ((millis() - lastDebounceTime) > debounceDelay) {
        lastDebounceTime = millis();
        return true;
      }
    }
  }
  return false;
}