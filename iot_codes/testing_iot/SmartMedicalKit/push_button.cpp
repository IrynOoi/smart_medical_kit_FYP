// ──────────────────────────────────────────────────────────────
// push_button.cpp – Push button implementation for ESP32 power control
// ──────────────────────────────────────────────────────────────

#include "push_button.h"
#include "esp_sleep.h"
#include "display_control.h"

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
// Setup push button with interrupt
// ──────────────────────────────────────────────────────────────
void setupPushButton() {
    // 使用 INPUT 模式（按钮已有外部上拉）
    pinMode(PUSH_BUTTON_PIN, INPUT);
    pinMode(LOCAL_LED_PIN, OUTPUT);
    digitalWrite(LOCAL_LED_PIN, LOW);
    
    // 检查是否从深度睡眠唤醒
    esp_sleep_wakeup_cause_t wakeup_cause = esp_sleep_get_wakeup_cause();
    if (wakeup_cause == ESP_SLEEP_WAKEUP_EXT0) {
        Serial.println("🔘 Woke up from deep sleep by button press");
        esp32Powered = true;
        updateDisplayState("MedSmart System", "Ready!");
    }
    
    // 使用 FALLING 中断（按钮按下时从 HIGH 到 LOW）
attachInterrupt(digitalPinToInterrupt(PUSH_BUTTON_PIN), pushButtonISR, RISING);
    
    Serial.println("✅ Push button initialized on D2");
    Serial.println("   Press once: Toggle ESP32 ON/OFF");
    
    // 打印当前按钮状态
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
    
    // 首次运行跳过
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
    updateDisplayState("MedSmart System", "Ready!");
    digitalWrite(LOCAL_LED_PIN, LOW);
}

// ──────────────────────────────────────────────────────────────
// Power off ESP32 (enter deep sleep)
// ──────────────────────────────────────────────────────────────
void powerOffESP32() {
    esp32Powered = false;
    Serial.println("🔋 ESP32 Powering OFF...");
    
    // 显示关机消息
    updateDisplayState("Goodbye", "");
    delay(500);
    
    // 关闭LED
    digitalWrite(LOCAL_LED_PIN, LOW);
    pinMode(LOCAL_LED_PIN, INPUT);
    
    // 配置唤醒引脚 - 按下时 LOW 唤醒
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
// 轮询检测（修正版）- 添加首次运行跳过
// ──────────────────────────────────────────────────────────────
void checkButtonState() {
    static unsigned long lastCheckTime = 0;
    static bool previousState = BUTTON_RELEASED;
    static bool firstRun = true;  // 首次运行标志
    
    if (millis() - lastCheckTime < 50) return;
    lastCheckTime = millis();
    
    int currentState = digitalRead(PUSH_BUTTON_PIN);
    
    // 首次运行：只记录状态，不执行任何操作
    if (firstRun) {
        firstRun = false;
        previousState = currentState;
        Serial.print("📊 Initial button state: ");
        Serial.println(currentState == BUTTON_PRESSED ? "PRESSED" : "RELEASED");
        return;
    }
    
    // 只有从 RELEASED → PRESSED 才触发（上升沿检测）
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