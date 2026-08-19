// push_button.cpp – Push button implementation for ESP32 power control

#include "push_button.h"
#include "esp_sleep.h"
#include "display_control.h"
#include "battery_monitor.h"

// Include WiFi and HTTP libraries
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

// Forward declarations for external variables
extern String serverBase;
extern const String deviceSerial;

// Button state variables
static volatile bool buttonState = BUTTON_RELEASED;
static volatile bool lastButtonState = BUTTON_RELEASED;
static volatile unsigned long lastDebounceTime = 0;
static volatile bool buttonPressed = false;
static volatile bool buttonPressDetected = false;

// ESP32 power state
static bool esp32Powered = true;

// LED pin
#define LOCAL_LED_PIN 18

// ──────────────────────────────────────────────────────────────
// Send power status to server via heartbeat
// ──────────────────────────────────────────────────────────────
void sendPowerStatusToServer(bool isAwake) {
    // Check if WiFi is connected
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("⚠️ WiFi not connected, cannot send power status");
        return;
    }
    
    String url = serverBase + "/device/heartbeat";
    
    Serial.print("📡 Sending power status to server: ");
    Serial.println(isAwake ? "AWAKE" : "SLEEPING");
    Serial.print("   URL: ");
    Serial.println(url);
    
    String deviceIP = WiFi.localIP().toString();
    long rssi = WiFi.RSSI();
    int batteryPct = readBatteryPercentage();
    String jsonPayload = "{\"device_serial\":\"" + deviceSerial + 
                         "\",\"battery\":" + String(batteryPct) + 
                         ",\"rssi\":" + String(rssi) + 
                         ",\"ip\":\"" + deviceIP + 
                         "\",\"is_awake\":" + String(isAwake ? "true" : "false") + "}";
    
    Serial.print("   Payload: ");
    Serial.println(jsonPayload);
    
    // Retry up to 3 times to ensure server receives the status before sleep
    for (int attempt = 1; attempt <= 3; attempt++) {
        HTTPClient http;
        WiFiClientSecure secureClient;
        secureClient.setInsecure();
        
        if (http.begin(secureClient, url)) {
            http.addHeader("Content-Type", "application/json");
            http.addHeader("ngrok-skip-browser-warning", "true");
            http.addHeader("Connection", "close");
            http.setConnectTimeout(10000);
            http.setTimeout(10000);
            http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
            
            int httpCode = http.POST(jsonPayload);
            if (httpCode > 0) {
                Serial.printf("✅ Power status sent successfully (Code: %d)\n", httpCode);
                http.end();
                secureClient.stop();
                return;
            } else {
                Serial.printf("❌ Attempt %d failed: %s (Code: %d)\n", attempt, http.errorToString(httpCode).c_str(), httpCode);
            }
            http.end();
            secureClient.stop();
        } else {
            Serial.printf("❌ Attempt %d: http.begin() failed for power status\n", attempt);
        }
        delay(500);
    }
}

// ──────────────────────────────────────────────────────────────
// Setup push button with interrupt
// ──────────────────────────────────────────────────────────────
void setupPushButton() {
    // Use INPUT mode (button has external pull-up)
    pinMode(PUSH_BUTTON_PIN, INPUT);
    pinMode(LOCAL_LED_PIN, OUTPUT);
    digitalWrite(LOCAL_LED_PIN, LOW);
    
    // Check if waking from deep sleep
    esp_sleep_wakeup_cause_t wakeup_cause = esp_sleep_get_wakeup_cause();
    if (wakeup_cause == ESP_SLEEP_WAKEUP_EXT0) {
        Serial.println("🔘 Woke up from deep sleep by button press");
        esp32Powered = true;
        updateDisplayState("MedSmart System", "Ready!");
    }
    
    // Use RISING interrupt (button press goes from LOW to HIGH)
    attachInterrupt(digitalPinToInterrupt(PUSH_BUTTON_PIN), pushButtonISR, RISING);
    
    Serial.println("✅ Push button initialized on D2");
    Serial.println("   Press once: Toggle ESP32 ON/OFF");
    
    // Print current button state
    int initialState = digitalRead(PUSH_BUTTON_PIN);
    Serial.print("   Current button state: ");
    Serial.println(initialState == BUTTON_PRESSED ? "PRESSED" : "RELEASED");
}

// ──────────────────────────────────────────────────────────────
// ISR for button state changes
// ──────────────────────────────────────────────────────────────
void IRAM_ATTR pushButtonISR() {
    buttonPressDetected = true;
}

// ──────────────────────────────────────────────────────────────
// Handle push button events (call this in main loop)
// ──────────────────────────────────────────────────────────────
void handlePushButton() {
    static bool firstRun = true;
    
    // Skip first run
    if (firstRun) {
        firstRun = false;
        return;
    }
    
    if (buttonPressDetected) {
        buttonPressDetected = false;
        
        delay(50);
        
        int currentState = digitalRead(PUSH_BUTTON_PIN);
        if (currentState == BUTTON_PRESSED) {
            Serial.println("🔘 Button pressed - Toggling power");
            togglePower();
        }
    }
}

// ──────────────────────────────────────────────────────────────
// Toggle ESP32 power on/off
// ──────────────────────────────────────────────────────────────
void togglePower() {
    Serial.print("🔄 TogglePower - Current: ");
    Serial.println(esp32Powered ? "ON" : "OFF");
    
    if (esp32Powered) {
        powerOffESP32();
    } else {
        powerOnESP32();
    }
}

// ──────────────────────────────────────────────────────────────
// Power on ESP32 (wake from sleep)
// ──────────────────────────────────────────────────────────────
void powerOnESP32() {
    esp32Powered = true;
    Serial.println("🔋 ESP32 Powered ON");
    
    // Send status to server that we're awake
    sendPowerStatusToServer(true);
    
    updateDisplayState("MedSmart System", "Ready!");
    digitalWrite(LOCAL_LED_PIN, LOW);
}

// ──────────────────────────────────────────────────────────────
// Power off ESP32 (enter deep sleep)
// ──────────────────────────────────────────────────────────────
void powerOffESP32() {
    esp32Powered = false;
    Serial.println("🔋 ESP32 Powering OFF...");
    
    // Send final status to server BEFORE sleeping
    sendPowerStatusToServer(false);
    delay(500);
    
    // Display sleep message
    updateDisplayState("Sleeping mode...", "");
    delay(500);
    
    // Turn off LED
    digitalWrite(LOCAL_LED_PIN, LOW);
    pinMode(LOCAL_LED_PIN, INPUT);
    
    // Configure wake-up pin - wake on HIGH (button pressed)
    esp_sleep_enable_ext0_wakeup(GPIO_NUM_2, HIGH);
    
    Serial.println("💤 Entering deep sleep...");
    delay(100);
    
    esp_deep_sleep_start();
}

// ──────────────────────────────────────────────────────────────
// Check if ESP32 is powered on
// ──────────────────────────────────────────────────────────────
bool isESP32Powered() {
    return esp32Powered;
}

// ──────────────────────────────────────────────────────────────
// Check if button is currently pressed
// ──────────────────────────────────────────────────────────────
bool isButtonPressed() {
    return (digitalRead(PUSH_BUTTON_PIN) == BUTTON_PRESSED);
}

// ──────────────────────────────────────────────────────────────
// Polling detection (corrected version) - skip first run
// ──────────────────────────────────────────────────────────────
void checkButtonState() {
    static unsigned long lastCheckTime = 0;
    static bool previousState = BUTTON_RELEASED;
    static bool firstRun = true;
    
    if (millis() - lastCheckTime < 50) return;
    lastCheckTime = millis();
    
    int currentState = digitalRead(PUSH_BUTTON_PIN);
    
    // First run: only record state, don't execute any action
    if (firstRun) {
        firstRun = false;
        previousState = currentState;
        Serial.print("📊 Initial button state: ");
        Serial.println(currentState == BUTTON_PRESSED ? "PRESSED" : "RELEASED");
        return;
    }
    
    // Only trigger from RELEASED → PRESSED (rising edge detection)
    if (currentState == BUTTON_PRESSED && previousState == BUTTON_RELEASED) {
        Serial.println("🔘 Button pressed (checkButtonState)");
        delay(50);
        if (digitalRead(PUSH_BUTTON_PIN) == BUTTON_PRESSED) {
            togglePower();
        }
        previousState = BUTTON_PRESSED;
    }
    else if (currentState == BUTTON_RELEASED && previousState == BUTTON_PRESSED) {
        previousState = BUTTON_RELEASED;
    }
}