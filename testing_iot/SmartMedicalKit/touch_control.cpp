//touch_control.cpp
#include <Arduino.h>

// Define pins
const int touchPin = 23;    // TTP223 I/O connected to D23

// State tracking
int lastTouchState = LOW;   

// Debounce settings (cooldown timer)
unsigned long lastDebounceTime = 0;  
const unsigned long debounceDelay = 300; // 300 milliseconds cooldown

void setupTouch() {
  // 加上 _PULLDOWN 强制在没有触摸时把引脚拉低，过滤杂波
  pinMode(touchPin, INPUT_PULLDOWN); 
}

void handleTouch() {
  int currentTouchState = digitalRead(touchPin);
  
  // Detect a "RISING EDGE" (went from LOW to HIGH)
  if (currentTouchState == HIGH && lastTouchState == LOW) {
    
    // Check if the cooldown period has passed
    if ((millis() - lastDebounceTime) > debounceDelay) {
      
      // Print a message to the Serial Monitor instead of turning on a buzzer
      Serial.println("✅ SUCCESS: Touch Button was pressed!");
      
      // Update the timer
      lastDebounceTime = millis(); 
    }
  }
  
  // Save the current state for the next loop
  lastTouchState = currentTouchState;
}