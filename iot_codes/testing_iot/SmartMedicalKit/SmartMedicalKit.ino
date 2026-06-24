// ──────────────────────────────────────────────────────────────
// SmartMedicalKit.ino – Main firmware for the ESP32‑based 
// medication dispenser. It handles:
//   • WiFi connection and HTTPS communication with the backend
//   • Polling for pending doses (via /pending_dose)
//   • Dispensing medication using stepper motors
//   • Buzzer alerts and OLED display feedback
//   • Heartbeat to keep the server informed of device status
//   • A built‑in web server for remote control / debugging
// ──────────────────────────────────────────────────────────────

// ── External libraries ────────────────────────────────────────
#include <WiFi.h>                   // WiFi connectivity
#include <WebServer.h>              // HTTP server for remote control
#include <WiFiClientSecure.h>       // HTTPS (SSL/TLS) client
#include <HTTPClient.h>             // HTTP/HTTPS requests
#include <ArduinoJson.h>            // JSON parsing / construction
#include <Preferences.h>            // Persistent storage (flash)

// ── Custom hardware abstraction layers ──────────────────────
#include "dispenser_motor.h"        // Stepper motor control functions
#include "buzzer_control.h"         // Buzzer on/off functions
#include "display_control.h"        // OLED display functions
#include "secrets.h"                // WiFi SSID + password (not in repo)

// ──────────────────────────────────────────────────────────────
// Global objects
// ──────────────────────────────────────────────────────────────
Preferences prefs;  // For saving server URL across reboots

// ── Server & device configuration ────────────────────────────
String serverBase = "https://reluctant-scrambled-badge.ngrok-free.dev"; 
// Default ngrok URL (can be changed at runtime via /config/seturl)

const String deviceSerial = "DISP-1";  // Unique device ID – must match backend

WebServer server(80);                  // HTTP server on port 80
const int ledPin = 18;                 // On‑board LED (for testing)

// ── Timers ────────────────────────────────────────────────────
unsigned long lastHeartbeatTime = 0;
const unsigned long heartbeatInterval = 30000;   // Send heartbeat every 30s

unsigned long lastDoseCheckTime = 0;
const unsigned long doseCheckInterval = 10000;   // Poll server every 10s

// ── Dose waiting state ──────────────────────────────────────
unsigned long doseStartTime = 0;
const unsigned long doseTimeout = 10000;         // 10 seconds to press the button

bool isDoseWaiting = false;          // True when a dose is due and awaiting user action
const int maxPendingDoses = 12;
struct PendingDose {
  int motorSlot;
  int adlogId;
  int prescriptionId;
  String medName;
  bool isEmpty;
};
PendingDose pendingDoses[maxPendingDoses];
int pendingDoseCount = 0;
String pendingMedName = "";          // Summary name for display

// ── Out‑of‑stock alarm state ────────────────────────────────
bool isOutOfStockBeeping = false;    // True when we are beeping because a slot is empty
unsigned long outOfStockStartTime = 0;
const unsigned long outOfStockTimeout = 10000;   // Beep for 10s then auto‑miss
unsigned long lastBuzzerToggleTime = 0;
bool outOfStockBuzzerState = false;  // Current buzzer state for toggling (beep pattern)

// ── Function prototypes (defined later) ─────────────────────
void setupTouch();  
void handleTouch(); 
void clearPendingDoses();
bool enqueuePendingDose(int motorSlot, int adlogId, int prescriptionId, const String& medName, bool isEmpty);
void markAllPendingAsMissed();
void showFirstPendingWarning();

// ──────────────────────────────────────────────────────────────
// Helper: Build full URL from a path
// ──────────────────────────────────────────────────────────────
String buildURL(String path) {
  return serverBase + path;
}

// ──────────────────────────────────────────────────────────────
// WiFi connection routine
// ──────────────────────────────────────────────────────────────
void connectToWiFi() {
  WiFi.disconnect(true);        // Clear any previous WiFi settings
  delay(1000); 
  WiFi.mode(WIFI_STA);          // Station mode (not AP)
  
  Serial.print("Connecting to WiFi: ");
  Serial.println(SECRET_SSID);
  updateDisplayState("Connecting...", "WiFi");   // Show on OLED
  
  WiFi.begin(SECRET_SSID, SECRET_PASS); 

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 40) {
    delay(500);
    Serial.print(".");
    retries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    updateDisplayState("MedSmart System", "Ready!");
  } else {
    Serial.println("\n❌ WiFi Connection Failed. Restarting...");
    updateDisplayState("Conn. Failed", "Restarting...");
    delay(2000);
    ESP.restart();
  }
}

// ──────────────────────────────────────────────────────────────
// HTTP Helper: Add common headers to every request
// ──────────────────────────────────────────────────────────────
void addCommonHeaders(HTTPClient &http) {
  http.addHeader("Content-Type", "application/json");
  http.addHeader("ngrok-skip-browser-warning", "true");  // Required for ngrok
  http.setConnectTimeout(10000);
  http.setTimeout(10000);
  http.addHeader("Connection", "close");   // Prevent keep‑alive issues
}

// ──────────────────────────────────────────────────────────────
// Mark a dose as successfully taken (called after motor rotation)
// ──────────────────────────────────────────────────────────────
void markDoseAsTaken(int adlogId, int prescriptionId) {
  HTTPClient http;
  String url = buildURL("/device/dispense_success");
  
  WiFiClientSecure secureClient;
  secureClient.setInsecure();   // Accept self‑signed / ngrok certificates

  http.begin(secureClient, url);
  addCommonHeaders(http);
  
  String payload = "{\"adlog_id\":" + String(adlogId) + ",\"prescription_id\":" + String(prescriptionId) + "}";
  int httpCode = http.POST(payload);
  
  if (httpCode == 200) {
    Serial.println("✅ Marked as TAKEN.");
  } else {
    Serial.print("❌ markDoseAsTaken failed. Code: ");
    Serial.println(httpCode);
  }
  http.end();
}

// ──────────────────────────────────────────────────────────────
// Mark a dose as missed (called on timeout or user cancellation)
// ──────────────────────────────────────────────────────────────
void markDoseAsMissed(int adlogId) {
  HTTPClient http;
  String url = buildURL("/device/dispense_missed");
  
  WiFiClientSecure secureClient;
  secureClient.setInsecure();

  http.begin(secureClient, url);
  addCommonHeaders(http);
  
  String payload = "{\"adlog_id\":" + String(adlogId) + "}";
  int httpCode = http.POST(payload);
  
  if (httpCode == 200) {
    Serial.println("⚠️ Marked as MISSED.");
  } else {
    Serial.print("❌ markDoseAsMissed failed. Code: ");
    Serial.println(httpCode);
  }
  http.end();
}

void clearPendingDoses() {
  pendingDoseCount = 0;
  pendingMedName = "";
}

bool enqueuePendingDose(int motorSlot, int adlogId, int prescriptionId, const String& medName, bool isEmpty) {
  if (pendingDoseCount >= maxPendingDoses) return false;
  pendingDoses[pendingDoseCount].motorSlot = motorSlot;
  pendingDoses[pendingDoseCount].adlogId = adlogId;
  pendingDoses[pendingDoseCount].prescriptionId = prescriptionId;
  pendingDoses[pendingDoseCount].medName = medName;
  pendingDoses[pendingDoseCount].isEmpty = isEmpty;
  pendingDoseCount++;
  if (pendingMedName.length() == 0) pendingMedName = medName;
  return true;
}

void markAllPendingAsMissed() {
  for (int i = 0; i < pendingDoseCount; i++) {
    markDoseAsMissed(pendingDoses[i].adlogId);
  }
}

void showFirstPendingWarning() {
  if (pendingDoseCount == 0) return;
  for (int i = 0; i < pendingDoseCount; i++) {
    if (pendingDoses[i].isEmpty) {
      updateDisplayState("Slot " + String(pendingDoses[i].motorSlot) + " Empty", "Refill " + pendingDoses[i].medName);
      return;
    }
  }
  updateDisplayState("Medicine Due!", pendingMedName);
}

// ──────────────────────────────────────────────────────────────
// Poll the server for any pending dose for this device
// ──────────────────────────────────────────────────────────────
void checkForPendingDose() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = buildURL("/device/" + deviceSerial + "/pending_dose");
  
  WiFiClientSecure secureClient;
  secureClient.setInsecure();

  http.begin(secureClient, url);
  http.addHeader("ngrok-skip-browser-warning", "true");
  http.setConnectTimeout(10000);
  http.setTimeout(10000);

  int httpCode = http.GET();
  
  if (httpCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(4096);
    deserializeJson(doc, payload);

    if (doc["success"] == true && doc["has_pending"] == true) {
      clearPendingDoses();
      bool hasEmptyDose = false;

      if (!doc["doses"].isNull()) {
        JsonArray doses = doc["doses"].as<JsonArray>();
        for (JsonVariant dose : doses) {
          bool isEmpty = dose["is_empty"] | false;
          if (isEmpty) hasEmptyDose = true;
          enqueuePendingDose(
            dose["motor_slot"] | 0,
            dose["adlog_id"] | 0,
            dose["prescription_id"] | 0,
            dose["medication_name"] | "Medicine",
            isEmpty
          );
        }
      } else if (!doc["data"].isNull()) {
        JsonVariant dose = doc["data"];
        bool isEmpty = dose["is_empty"] | (doc["is_empty"] | false);
        if (isEmpty) hasEmptyDose = true;
        enqueuePendingDose(
          dose["motor_slot"] | 0,
          dose["adlog_id"] | 0,
          dose["prescription_id"] | 0,
          dose["medication_name"] | "Medicine",
          isEmpty
        );
      }

      if (pendingDoseCount > 0) {
        Serial.println("🚨 Dose batch due. Count: " + String(pendingDoseCount));
        isDoseWaiting = true;
        isOutOfStockBeeping = hasEmptyDose;
        doseStartTime = millis();
        if (hasEmptyDose) {
          outOfStockStartTime = millis();
          lastBuzzerToggleTime = millis();
          outOfStockBuzzerState = true;
        }
        triggerBuzzerHardware(true);
        showFirstPendingWarning();
      }
    }
  } else {
    Serial.print("⚠️ checkForPendingDose HTTP code: ");
    Serial.println(httpCode);
  }
  http.end();
}

// ──────────────────────────────────────────────────────────────
// Dispense action – called when the physical touch button is pressed
// ──────────────────────────────────────────────────────────────
void executeDispense() {
  // If we are in standalone out‑of‑stock alarm, pressing the button dismisses it
  if (isOutOfStockBeeping && !isDoseWaiting) {
    Serial.println("🛑 User dismissed out-of-stock alarm.");
    isOutOfStockBeeping = false;
    triggerBuzzerHardware(false);
    updateDisplayState("MedSmart System", "Ready!"); 
    return;
  }

  // Batch dose waiting: dispense each due medication sequentially
  if (isDoseWaiting) {
    isDoseWaiting = false; 
    isOutOfStockBeeping = false;
    triggerBuzzerHardware(false);
    
    for (int i = 0; i < pendingDoseCount; i++) {
      PendingDose dose = pendingDoses[i];
      if (dose.isEmpty) {
        Serial.println("⚠️ Out of stock: " + dose.medName + " (Slot " + String(dose.motorSlot) + ")");
        updateDisplayState("Slot " + String(dose.motorSlot) + " Empty", "Refill " + dose.medName);
        delay(1200);
        if (WiFi.status() == WL_CONNECTED) markDoseAsMissed(dose.adlogId);
        continue;
      }

      Serial.println("⚙️ Dispensing: " + dose.medName);
      updateDisplayState("Dispensing...", dose.medName);
      rotateMotorHardware(dose.motorSlot);
      if (WiFi.status() == WL_CONNECTED) {
        markDoseAsTaken(dose.adlogId, dose.prescriptionId);
      }
      delay(1200);
    }
    
    updateDisplayState("Finished!", "Take Meds");
    delay(4000); 
    clearPendingDoses();
    updateDisplayState("MedSmart System", "Ready!"); 
  }
}

// ──────────────────────────────────────────────────────────────
// Arduino setup() – runs once on power‑up
// ──────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // ── Load saved server URL from flash (persistent across reboots) ──
  prefs.begin("medsmart", false);
  String savedURL = prefs.getString("server_url", "");
  if (savedURL.length() > 0) {
    serverBase = savedURL;
    Serial.println("📡 Loaded server URL from flash: " + serverBase);
  }
  prefs.end();
  
  // ── Initialise hardware ──────────────────────────────────────
  pinMode(ledPin, OUTPUT);
  setupStepper();    // from dispenser_motor.h
  setupBuzzer();     // from buzzer_control.h
  setupDisplay();    // from display_control.h
  setupTouch();      // defined below (or in another file)

  // ── Connect to WiFi ─────────────────────────────────────────
  connectToWiFi();

  // ── Set up HTTP server endpoints ────────────────────────────
  
  // LED control (for testing)
  server.on("/led/on", []() {
    digitalWrite(ledPin, HIGH);
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "text/plain", "LED IS ON");
  });
  server.on("/led/off", []() {
    digitalWrite(ledPin, LOW);
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "text/plain", "LED IS OFF");
  });

  // Buzzer, display, and motor endpoints – functions are defined in the included headers
  server.on("/buzzer/on",      handleBuzzerOn);
  server.on("/buzzer/off",     handleBuzzerOff);
  server.on("/display/hello",  handleDisplayHello);
  server.on("/display/clear",  handleDisplayClear);
  server.on("/display/sv",     handleDisplaySV);   // Show system info (IP, etc.)
  
  // Stepper motor 1 (slot 1)
  server.on("/stepper/forward",   handleMotorForward);
  server.on("/stepper/backward",  handleMotorBackward);
  server.on("/stepper/90",        handleMotor90);
  server.on("/stepper/180",       handleMotor180);

  // Stepper motor 2 (slot 2)
  server.on("/stepper2/forward",  handleMotor2Forward);
  server.on("/stepper2/backward", handleMotor2Backward);
  server.on("/stepper2/90",       handleMotor290);
  server.on("/stepper2/180",      handleMotor2180);

  // Stepper motor 3 (slot 3)
  server.on("/stepper3/forward",  handleMotor3Forward);
  server.on("/stepper3/backward", handleMotor3Backward);
  server.on("/stepper3/90",       handleMotor390);
  server.on("/stepper3/180",      handleMotor3180);

  // ── Special endpoint for retake (initiated by the backend) ──
  server.on("/retake", HTTP_GET, []() {
    if (server.hasArg("adlog_id") && server.hasArg("prescription_id") && server.hasArg("slot")) {
      int adlogId = server.arg("adlog_id").toInt();
      int prescriptionId = server.arg("prescription_id").toInt();
      int motorSlot = server.arg("slot").toInt();
      String medName = server.hasArg("med_name") ? server.arg("med_name") : "Medicine";

      // Cancel any ongoing out‑of‑stock or normal waiting
      isOutOfStockBeeping = false;
      triggerBuzzerHardware(false);
      clearPendingDoses();

      // Put the device into dose‑waiting mode with a single queued retake dose
      if (!enqueuePendingDose(motorSlot, adlogId, prescriptionId, medName, false)) {
        server.send(500, "text/plain", "Retake queue full");
        return;
      }
      isDoseWaiting = true;
      doseStartTime = millis();
      triggerBuzzerHardware(true);
      showFirstPendingWarning();

      server.send(200, "text/plain", "Retake started");
    } else {
      server.send(400, "text/plain", "Missing parameters: adlog_id, prescription_id, slot");
    }
  });

  // ── Configuration endpoint: update server URL without re‑flashing ──
  server.on("/config/seturl", []() {
    if (server.hasArg("url")) {
      String newURL = server.arg("url");
      prefs.begin("medsmart", false);
      prefs.putString("server_url", newURL);
      prefs.end();
      serverBase = newURL;
      server.send(200, "text/plain", "Server URL updated to: " + newURL + ". No restart needed.");
      Serial.println("📡 Server URL updated to: " + newURL);
    } else {
      server.send(400, "text/plain", "Usage: /config/seturl?url=https://your-ngrok-url.ngrok-free.app");
    }
  });

  // ── Configuration status endpoint ──
  server.on("/config/status", []() {
    String json = "{\"server_url\":\"" + serverBase + "\",\"device_serial\":\"" + deviceSerial + "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
    server.send(200, "application/json", json);
  });

  // ── Start the HTTP server ──
  server.begin();
  Serial.println("🚀 HTTP server started");
}

// ──────────────────────────────────────────────────────────────
// Arduino loop() – runs continuously
// ──────────────────────────────────────────────────────────────
void loop() {
  handleTouch();      // Check if the physical button was pressed
  server.handleClient(); // Process incoming HTTP requests

  // 1. WiFi watchdog – reconnect if disconnected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi lost. Reconnecting...");
    WiFi.disconnect();
    WiFi.begin(SECRET_SSID, SECRET_PASS); 
    delay(2000); 
  }

  // 2. Poll for pending dose from the server (only if not already waiting)
  if (WiFi.status() == WL_CONNECTED) {
    if (!isDoseWaiting && !isOutOfStockBeeping && (millis() - lastDoseCheckTime > doseCheckInterval)) {
      checkForPendingDose();
      lastDoseCheckTime = millis();
    }
  }

  // 3A. Standalone out‑of‑stock beeping pattern (toggle buzzer every 500 ms)
  if (isOutOfStockBeeping && !isDoseWaiting) {
    if (millis() - outOfStockStartTime > outOfStockTimeout) {
      // Timeout – automatically miss the dose and stop beeping
      isOutOfStockBeeping = false;
      triggerBuzzerHardware(false);
      Serial.println("🛑 Out-of-stock timeout.");
      updateDisplayState("MedSmart System", "Ready!");
    } else {
      if (millis() - lastBuzzerToggleTime > 500) {
        outOfStockBuzzerState = !outOfStockBuzzerState;
        triggerBuzzerHardware(outOfStockBuzzerState);
        lastBuzzerToggleTime = millis();
      }
    }
  }

  // 3B. Normal dose timeout – user didn't press the button in time
  if (isDoseWaiting) {
    if (millis() - doseStartTime > doseTimeout) {
      Serial.println("⏰ Dose timeout — batch marked as missed.");
      isDoseWaiting = false; 
      isOutOfStockBeeping = false;
      triggerBuzzerHardware(false); 
      updateDisplayState("Missed Dose", pendingMedName);
      if (WiFi.status() == WL_CONNECTED) markAllPendingAsMissed();
      clearPendingDoses();
      delay(4000);
      updateDisplayState("MedSmart System", "Ready!"); 
    }
  }

  // 4. Heartbeat – send device status to the server every 30 seconds
  if (millis() - lastHeartbeatTime > heartbeatInterval) {
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = buildURL("/device/heartbeat");

      Serial.println("💓 Sending heartbeat to: " + url);

      WiFiClientSecure secureClient;
      secureClient.setInsecure();   // Accept ngrok's self‑signed certificate

      if (http.begin(secureClient, url)) {
        addCommonHeaders(http);
        http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

        String deviceIP = WiFi.localIP().toString();
        long rssi = WiFi.RSSI(); 
        String jsonPayload = "{\"device_serial\":\"" + deviceSerial + "\",\"battery\":100,\"rssi\":" + String(rssi) + ",\"ip\":\"" + deviceIP + "\"}";
        
        int httpCode = http.POST(jsonPayload);
        if (httpCode > 0) {
          Serial.println("💓 Heartbeat OK. Code: " + String(httpCode));
        } else {
          Serial.println("❌ Heartbeat failed: " + http.errorToString(httpCode));
        }
        http.end();
      } else {
        Serial.println("❌ http.begin() failed for heartbeat.");
      }
    }
    lastHeartbeatTime = millis();
  }
}