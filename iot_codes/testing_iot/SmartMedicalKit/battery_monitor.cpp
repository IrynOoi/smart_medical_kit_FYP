// battery_monitor.cpp – Implementation of battery sensing & percentage calculation
#include "battery_monitor.h"

// Multi-sample count to filter ADC noise from WiFi and motor switching
#define ADC_SAMPLE_COUNT 20

void setupBatteryMonitor() {
  pinMode(BATTERY_ADC_PIN, INPUT);
  // Set ADC resolution to 12 bits (0 - 4095)
  analogReadResolution(12);
  // Set ADC attenuation to 11dB (0V - 3.3V full-scale input range on ESP32)
  analogSetAttenuation(ADC_11db);
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);
  Serial.printf("🔋 Battery Monitor initialized on GPIO %d (Divider Ratio: %.2f)\n", BATTERY_ADC_PIN, VOLTAGE_DIVIDER_RATIO);
}

float readBatteryVoltage() {
  uint32_t adcSum = 0;
  for (int i = 0; i < ADC_SAMPLE_COUNT; i++) {
    adcSum += analogRead(BATTERY_ADC_PIN);
    delayMicroseconds(200);
  }
  float avgAdc = (float)adcSum / (float)ADC_SAMPLE_COUNT;

  // Convert 12-bit ADC value (0 - 4095) to measured pin voltage (0 - 3.3V)
  float pinVoltage = (avgAdc / 4095.0f) * 3.3f;

  // Calculate actual battery voltage before the voltage divider
  float batteryVoltage = pinVoltage * VOLTAGE_DIVIDER_RATIO;

  Serial.printf("🔍 [ADC GPIO %d] Raw ADC: %d | Pin V: %.3fV | Bat V: %.2fV\n", 
                BATTERY_ADC_PIN, (int)avgAdc, pinVoltage, batteryVoltage);

  return batteryVoltage;
}

int readBatteryPercentage() {
  float voltage = readBatteryVoltage();

  // If ADC is disconnected or near 0V, return 0%
  if (voltage < 2.0f) {
    return 0;
  }

  // If fully charged or slightly above 4.20V (due to charging boost), clamp to 100%
  if (voltage >= BATTERY_MAX_V) {
    return 100;
  }
  if (voltage <= BATTERY_MIN_V) {
    return 0;
  }

  // Linear interpolation between cutoff (3.30V) and full (4.20V)
  float percentage = ((voltage - BATTERY_MIN_V) / (BATTERY_MAX_V - BATTERY_MIN_V)) * 100.0f;

  int pct = (int)round(percentage);
  if (pct > 100) pct = 100;
  if (pct < 0) pct = 0;
  return pct;
}

void handleBatteryStatus() {
  float voltage = readBatteryVoltage();
  int percentage = readBatteryPercentage();
  int rawAdc = analogRead(BATTERY_ADC_PIN);

  String json = "{";
  json += "\"success\":true,";
  json += "\"battery_percentage\":" + String(percentage) + ",";
  json += "\"battery_voltage\":" + String(voltage, 2) + ",";
  json += "\"raw_adc\":" + String(rawAdc) + ",";
  json += "\"pin\":" + String(BATTERY_ADC_PIN) + ",";
  json += "\"divider_ratio\":" + String(VOLTAGE_DIVIDER_RATIO, 2);
  json += "}";

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}
