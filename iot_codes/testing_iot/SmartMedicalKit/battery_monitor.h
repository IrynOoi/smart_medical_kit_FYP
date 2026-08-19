// battery_monitor.h – Battery voltage & percentage measurement for LX-2BUPS Boost Module
#ifndef BATTERY_MONITOR_H
#define BATTERY_MONITOR_H

#include <Arduino.h>
#include <WebServer.h>

extern WebServer server;

// ── Pin & Hardware Configuration ──────────────────────────────────────────
// Use an ADC1 pin (safe to use while WiFi is active: GPIO 34, 35, 36, 39)
// Default is GPIO 35 (A7 / ADC1_CH7)
#ifndef BATTERY_ADC_PIN
#define BATTERY_ADC_PIN 35
#endif

// ── Voltage Divider Configuration ─────────────────────────────────────────
// Circuit wiring:
// LX-2BUPS Battery (+) ──[ R1: 100kΩ ]──┬──[ R2: 100kΩ ]── GND (ESP32)
//                                       │
//                                 BATTERY_ADC_PIN (GPIO 35)
//
// With equal resistors (100kΩ & 100kΩ), Divider Ratio = (R1 + R2) / R2 = 2.0
// 4.2V Max Battery Voltage -> 2.10V at ADC Pin (Safely within 0~3.3V range)
#define R1_OHMS 100000.0f
#define R2_OHMS 100000.0f
#define VOLTAGE_DIVIDER_RATIO ((R1_OHMS + R2_OHMS) / R2_OHMS)

// ── Battery Parameters (Single-Cell 3.7V / 4.2V Li-ion Battery) ───────────
#define BATTERY_MIN_V 3.30f  // 0% cutoff voltage
#define BATTERY_MAX_V 4.20f  // 100% full charge voltage

// ── Function Prototypes ───────────────────────────────────────────────────
void setupBatteryMonitor();
float readBatteryVoltage();
int readBatteryPercentage();
void handleBatteryStatus();

#endif // BATTERY_MONITOR_H
