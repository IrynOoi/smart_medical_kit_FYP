// display_control.cpp
#include "display_control.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>

#define i2c_Address 0x3C 
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1   

Adafruit_SH1106G display = Adafruit_SH1106G(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setupDisplay() {
  delay(1000); // 等待 Serial Monitor 准备好
  Serial.println("\n--- Starting OLED Setup ---");

  // 1. 强制唤醒 ESP32 的 I2C 通讯 (SDA=21, SCL=22)
Wire.begin(32, 33); // SDA=32, SCL=33
  // 2. 迷你硬件扫描器：检查板子到底有没有连上屏幕
  Serial.println("Scanning I2C bus for OLED...");
  byte error, address;
  int nDevices = 0;
  for(address = 1; address < 127; address++ ) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    if (error == 0) {
      Serial.print("✅ Found Screen at address: 0x");
      Serial.println(address, HEX);
      nDevices++;
    }
  }

  if (nDevices == 0) {
    Serial.println("❌ ERROR: Cannot find screen! (Hardware issue)");
  }

  // 3. 初始化屏幕
  if(!display.begin(i2c_Address, true)) {
    Serial.println(F("❌ SH1106 Screen allocation failed!"));
    return;
  }

  // 4. 强制把屏幕亮度调到最高
  display.setContrast(255);

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 10);
  display.println("Smart Medical Kit");
  display.println("System Ready!");
  display.display(); 
  Serial.println("✅ OLED Display Initialized Successfully!");
}

void handleDisplayHello() {
  Serial.println("Displaying Hello World");
  display.clearDisplay();
  display.setTextSize(2); 
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 15);
  display.println("Hello");
  display.println("World!");
  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Hello world displayed on OLED");
}

void handleDisplayClear() {
  Serial.println("Clearing Display");
  display.clearDisplay();
  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "OLED Display Cleared");
}

void handleDisplaySV() {
  Serial.println("Displaying SV Name");
  display.clearDisplay();
  
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 0);
  display.println("Supervisor:");
  
  display.setTextSize(1); 
  display.setCursor(0, 20);
  display.println("Assoc. Prof. Ts. Dr.");
  
  display.setTextSize(2); 
  display.setCursor(0, 35);
  display.println("Sabrina");
  display.println("Ahmad");
  
  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "SV Name displayed");
}