// touch_control.cpp
#include <Arduino.h>

const int touchPin = 23;    
int lastTouchState = LOW;   
unsigned long lastDebounceTime = 0;  
const unsigned long debounceDelay = 500;

// ✅ Forward declarations
bool checkTouch();
void checkAndDispenseDose();

void setupTouch() {
  pinMode(touchPin, INPUT_PULLDOWN); 
}

void handleTouch() {
  if (checkTouch()) {
    Serial.println("👆 Touch detected!");
    checkAndDispenseDose();
  }
}

bool checkTouch() {
  int currentTouchState = digitalRead(touchPin);
  bool isTouched = false;
  
  if (currentTouchState == HIGH && lastTouchState == LOW) {
    if ((millis() - lastDebounceTime) > debounceDelay) {
      lastDebounceTime = millis();
      isTouched = true;
    }
  }
  
  lastTouchState = currentTouchState;
  return isTouched;
}