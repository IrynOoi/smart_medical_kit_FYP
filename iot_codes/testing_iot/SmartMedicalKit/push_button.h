// push_button.h – Push button control for ESP32 power on/off

#ifndef PUSH_BUTTON_H
#define PUSH_BUTTON_H

#include <Arduino.h>

// Pin definitions
#define PUSH_BUTTON_PIN 2    // D2 pin on ESP32

// Button states
#define BUTTON_PRESSED HIGH    // 高电平输出模块：按下是 HIGH
#define BUTTON_RELEASED LOW    // 高电平输出模块：释放是 LOW

// Timing constants
#define DEBOUNCE_DELAY 50

// Function prototypes
void setupPushButton();
void handlePushButton();
void pushButtonISR();
bool isButtonPressed();
void togglePower();
void powerOnESP32();
void powerOffESP32();
bool isESP32Powered();
void checkButtonState();

// New function for sending power status to server
void sendPowerStatusToServer(bool isAwake);

#endif // PUSH_BUTTON_H