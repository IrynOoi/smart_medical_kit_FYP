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
  delay(1000); // 留着这个延时，防止启动抢跑
  Serial.println("\n--- Starting OLED Setup ---");

  // 🌟 核心修复：将针脚改回 21 (SDA) 和 22 (SCL)
  Wire.begin(21, 22); 
  
  // 2. 迷你硬件扫描器
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

void handleDisplaySV() {
  Serial.println("Displaying SV Name");
  display.clearDisplay();
  
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 0);
  display.println("Supervisor:");
  
  display.setTextSize(1); 
  display.setCursor(0, 15);
  display.println("Dr");
  
  // 💡 友情提示：Size 2 的字体非常大，一行大概只能显示 10 个字母左右。
  // "Noorrezam bin Yusop" 太长了，用 Size 2 肯定会超出屏幕换行，导致排版很难看。
  // 我建议把名字的字体改回 Size 1，或者分两行写。这里我帮你改成了 Size 1。
  display.setTextSize(1); 
  display.setCursor(0, 30);
  display.println("Noorrezam bin Yusop");

  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "SV Name displayed");
}

void updateDisplayState(String title, String subtitle) {
  display.clearDisplay();
  
  // Print Top Title (smaller)
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println(title);
  
  // Print Main Subtitle (bigger)
  display.setTextSize(2);
  display.setCursor(0, 20);
  display.println(subtitle);
  
  display.display();
}

void handleDisplayClear() {
  Serial.println("Clearing Display");
  display.clearDisplay();
  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "OLED Display Cleared");
}