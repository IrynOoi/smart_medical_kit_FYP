// battery_monitor.cpp – Implementation of battery sensing & percentage calculation
#include "battery_monitor.h"
#include <algorithm>
#include <math.h>

// ── Filter Parameters ───────────────────────────────────────────────────────
// Multi-sample count: Collect 64 samples
#define ADC_SAMPLE_COUNT 64
// Trim count: Discard the 8 lowest and 8 highest samples (64 - 16 = 48 averaged)
#define TRIM_COUNT 8
// Exponential Moving Average weight: 0.20 (20% new reading, 80% previous smooth)
#define EMA_ALPHA 0.20f

// Static filter states
static float s_filteredVoltage = -1.0f;
static int s_stablePercentage = -1;
static unsigned long s_lastSampleTime = 0;

void setupBatteryMonitor() {
  pinMode(BATTERY_ADC_PIN, INPUT);
  // Set ADC resolution to 12 bits (0 - 4095)
  analogReadResolution(12);
  // Set ADC attenuation to 11dB (0V - 3.3V full-scale input range on ESP32)
  analogSetAttenuation(ADC_11db);
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);

  // Initial read to initialize EMA and percentage immediately without startup delay
  s_filteredVoltage = readBatteryVoltage();
  s_stablePercentage = readBatteryPercentage();

  Serial.printf("🔋 Battery Monitor initialized on GPIO %d (Divider: %.2f | Initial: %.2fV / %d%%)\n", 
                BATTERY_ADC_PIN, VOLTAGE_DIVIDER_RATIO, s_filteredVoltage, s_stablePercentage);
}

float readBatteryVoltage() {
  unsigned long now = millis();
  // Return cached filtered voltage if sampled recently (< 500ms) to avoid duplicate readings
  if (s_filteredVoltage > 0.0f && (now - s_lastSampleTime < 500)) {
    return s_filteredVoltage;
  }

  // 1. Collect multi-samples
  int samples[ADC_SAMPLE_COUNT];
  for (int i = 0; i < ADC_SAMPLE_COUNT; i++) {
    samples[i] = analogRead(BATTERY_ADC_PIN);
    delayMicroseconds(100);
  }

  // 2. Sort samples to perform Trimmed Mean (discard noise spikes/WiFi bursts)
  std::sort(samples, samples + ADC_SAMPLE_COUNT);

  uint32_t adcSum = 0;
  int validCount = ADC_SAMPLE_COUNT - (TRIM_COUNT * 2);
  for (int i = TRIM_COUNT; i < ADC_SAMPLE_COUNT - TRIM_COUNT; i++) {
    adcSum += samples[i];
  }
  float avgAdc = (float)adcSum / (float)validCount;

  // Convert 12-bit ADC value to measured pin voltage (0 - 3.3V)
  float pinVoltage = (avgAdc / 4095.0f) * 3.3f;

  // Calculate actual battery voltage before the voltage divider
  float instantVoltage = pinVoltage * VOLTAGE_DIVIDER_RATIO;

  // 3. Exponential Moving Average (EMA) Filter
  if (s_filteredVoltage < 0.0f) {
    // First read: initialize directly
    s_filteredVoltage = instantVoltage;
  } else if (fabs(instantVoltage - s_filteredVoltage) > 0.35f) {
    // Large voltage change (e.g., USB charger plugged in/out or battery swapped): fast adapt
    s_filteredVoltage = instantVoltage;
  } else {
    // Smooth EMA transition
    s_filteredVoltage = (EMA_ALPHA * instantVoltage) + ((1.0f - EMA_ALPHA) * s_filteredVoltage);
  }

  s_lastSampleTime = now;

  Serial.printf("🔍 [ADC GPIO %d] Raw ADC (Trimmed): %d | Pin V: %.3fV | Instant: %.2fV | Filtered: %.2fV\n", 
                BATTERY_ADC_PIN, (int)avgAdc, pinVoltage, instantVoltage, s_filteredVoltage);

  return s_filteredVoltage;
}

int readBatteryPercentage() {
  float voltage = readBatteryVoltage();

  // If ADC is disconnected or near 0V, return 0%
  if (voltage < 2.0f) {
    s_stablePercentage = 0;
    return 0;
  }

  // Clamp boundaries
  if (voltage >= BATTERY_MAX_V) {
    s_stablePercentage = 100;
    return 100;
  }
  if (voltage <= BATTERY_MIN_V) {
    s_stablePercentage = 0;
    return 0;
  }

  // Linear calculation based on filtered voltage
  float rawPercentage = ((voltage - BATTERY_MIN_V) / (BATTERY_MAX_V - BATTERY_MIN_V)) * 100.0f;
  int targetPct = (int)round(rawPercentage);
  if (targetPct > 100) targetPct = 100;
  if (targetPct < 0) targetPct = 0;

  // 4. Anti-bounce / Hysteresis logic
  if (s_stablePercentage < 0) {
    s_stablePercentage = targetPct;
  } else {
    // If dropping: allow drop smoothly
    if (targetPct < s_stablePercentage) {
      s_stablePercentage = targetPct;
    }
    // If rising (charging or noise): only update upward if it's a solid rise (>= +2%)
    // This prevents 53% <-> 54% fluttering on the border
    else if (targetPct >= s_stablePercentage + 2) {
      s_stablePercentage = targetPct;
    }
  }

  return s_stablePercentage;
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
