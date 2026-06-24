// display_control.cpp
// This file provides functions to initialize and control an OLED display (SH1106)
// over I2C. It includes handlers for displaying messages like "Hello World",
// supervisor name, and clearing the screen. The display is used to show system
// status and user information.
// The I2C pins are explicitly set to 21 (SDA) and 22 (SCL) to match hardware wiring.

#include "display_control.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>

// OLED I2C address (common for SH1106)
#define i2c_Address 0x3C 
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1   // No reset pin used

// Create the display object with the specified dimensions and I2C bus
Adafruit_SH1106G display = Adafruit_SH1106G(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ========================================================
// Setup function – called once at system startup
// Initializes I2C, scans for the OLED, and shows a welcome message.
// ========================================================
void setupDisplay() {
  // Small delay to allow power to stabilize before I2C communication
  delay(1000);
  Serial.println("\n--- Starting OLED Setup ---");

  // Explicitly set I2C pins to 21 (SDA) and 22 (SCL) – this is critical for correct wiring.
  Wire.begin(21, 22); 
  
  // Scan the I2C bus to detect connected devices (useful for debugging)
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

  // Attempt to initialize the display with the given I2C address
  if(!display.begin(i2c_Address, true)) {
    Serial.println(F("❌ SH1106 Screen allocation failed!"));
    return;
  }

  // Set maximum contrast for clear visibility
  display.setContrast(255);

  // Clear the buffer and show a startup message
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 10);
  display.println("Smart Medical Kit");
  display.println("System Ready!");
  display.display(); 
  Serial.println("✅ OLED Display Initialized Successfully!");
}

// ========================================================
// HTTP handler – displays "Hello World" on the OLED
// ========================================================
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

// ========================================================
// HTTP handler – displays supervisor name (Dr Noorrezam bin Yusop)
// ========================================================
void handleDisplaySV() {
  Serial.println("Displaying SV Name");
  display.clearDisplay();
  
  // Show label "Supervisor:" in small font
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 0);
  display.println("Supervisor:");
  
  // Show title "Dr" in small font
  display.setTextSize(1); 
  display.setCursor(0, 15);
  display.println("Dr");
  
  // Show the full name. Using size 1 ensures the long name fits on one line.
  // (Size 2 would be too large and cause ugly wrapping.)
  display.setTextSize(1); 
  display.setCursor(0, 30);
  display.println("Noorrezam bin Yusop");

  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "SV Name displayed");
}

// ========================================================
// Generic function to update display with a title (small) and subtitle (large)
// Useful for dynamic status messages from other parts of the system.
// ========================================================
void updateDisplayState(String title, String subtitle) {
  display.clearDisplay();
  
  // Print top title in small font
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println(title);
  
  // Print main subtitle in large font
  display.setTextSize(2);
  display.setCursor(0, 20);
  display.println(subtitle);
  
  display.display();
}

// ========================================================
// HTTP handler – clears the OLED screen completely
// ========================================================
void handleDisplayClear() {
  Serial.println("Clearing Display");
  display.clearDisplay();
  display.display();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "OLED Display Cleared");
}