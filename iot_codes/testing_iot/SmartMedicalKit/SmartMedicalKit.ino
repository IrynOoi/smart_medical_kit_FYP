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
#include <WiFiManager.h>            // ⬅️ WiFiManager Captive Portal Library

// ── Custom hardware abstraction layers ──────────────────────
#include "dispenser_motor.h"        // Stepper motor control functions
#include "buzzer_control.h"         // Buzzer on/off functions
#include "display_control.h"        // OLED display functions
#include "push_button.h"
#include "battery_monitor.h"

// ──────────────────────────────────────────────────────────────
// Global objects
// ──────────────────────────────────────────────────────────────
Preferences prefs;  // For saving server URL across reboots

// ── Server & device configuration ────────────────────────────
String serverBase = "https://preschool-quality-papaya.ngrok-free.dev"; 
// Default ngrok URL (can be changed at runtime via /config/seturl)

extern const String deviceSerial = "DISP-1";  // Unique device ID – must match backend

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
const int maxPendingDoses = 12;      // Safety cap to keep RAM usage predictable on ESP32
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
void sendPowerStatusToServer(bool isAwake); 

// ──────────────────────────────────────────────────────────────
// Helper: Build full URL from a path
// ──────────────────────────────────────────────────────────────
String buildURL(String path) {
  return serverBase + path;
}

// ──────────────────────────────────────────────────────────────
// WiFi connection routine using WiFiManager Captive Portal
// ──────────────────────────────────────────────────────────────
void connectToWiFi() {
  Serial.println("\n=================================");
  Serial.println("🌐 Starting WiFi Connection (WiFiManager)...");
  Serial.println("=================================");
  updateDisplayState("WiFi Setup AP", "MedSmart-Setup");

  WiFiManager wm;

  // Set timeout of 180 seconds for captive portal before restarting
  wm.setConfigPortalTimeout(180);

  // Automatically connects to saved WiFi, OR starts AP "MedSmart-Setup"
  // and stays open until user configures it on phone/PC!
  bool res = wm.autoConnect("MedSmart-Setup");

  if (!res) {
    Serial.println("\n❌ Failed to connect or portal timed out. Restarting...");
    updateDisplayState("Setup Failed", "Restarting...");
    delay(2000);
    ESP.restart();
  } else {
    Serial.println("\n✅ WiFi Connected Successfully!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    updateDisplayState("MedSmart System", "Ready!");
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
    DynamicJsonDocument doc(4096);   // Batch payload buffer (supports multiple due doses)
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
          triggerBuzzerHardware(true);
        } else {
          triggerBuzzerHardware(true);
        }
        showFirstPendingWarning();
      } // closes if (pendingDoseCount > 0)
    } // closes if (doc["success"]...)
  } // closes if (httpCode == 200)
  http.end();
} // closes checkForPendingDose()

// ──────────────────────────────────────────────────────────────
// Dispense action – called when the physical touch button is pressed
// ──────────────────────────────────────────────────────────────
void executeDispense() {
  // If there is a pending dose batch, process it.
  // The out‑of‑stock alarm (if active) is NOT dismissed by this button press.
  if (isDoseWaiting) {
    // Remember whether the out‑of‑stock alarm is active.
    bool wasOutOfStock = isOutOfStockBeeping;

    // Only turn off the buzzer if there is NO out‑of‑stock condition.
    // If out‑of‑stock is active, the buzzer will continue to be toggled by the loop.
    if (!wasOutOfStock) {
      triggerBuzzerHardware(false);
    }

    // Process all pending doses.
    for (int i = 0; i < pendingDoseCount; i++) {
      PendingDose dose = pendingDoses[i];

      if (dose.isEmpty) {
        Serial.println("⚠️ Out of stock: " + dose.medName + " (Slot " + String(dose.motorSlot) + ")");
        updateDisplayState("Slot " + String(dose.motorSlot) + " Empty", "Refill " + dose.medName);
        if (WiFi.status() == WL_CONNECTED) {
          markDoseAsMissed(dose.adlogId);
        }
        // Do NOT stop the out‑of‑stock alarm; it will continue in the loop.
        continue;
      }

      Serial.println("⚙️ Dispensing: " + dose.medName);
      updateDisplayState("Dispensing...", dose.medName);
      rotateMotorHardware(dose.motorSlot);
      if (WiFi.status() == WL_CONNECTED) {
        markDoseAsTaken(dose.adlogId, dose.prescriptionId);
      }
    }

    // Clear the queue and mark that we are no longer waiting for a dose.
    clearPendingDoses();
    isDoseWaiting = false;

    // IMPORTANT: Do NOT set isOutOfStockBeeping = false here.
    // The alarm will continue until the out‑of‑stock timeout expires in loop().

    updateDisplayState("Finished!", "Take Meds");
    delay(4000);
    updateDisplayState("MedSmart System", "Ready!");
  }
  // If there is no pending dose, pressing the button does nothing.
}

// ──────────────────────────────────────────────────────────────
// Arduino setup() – runs once on power‑up
// ──────────────────────────────────────────────────────────────
void setup() 
{
  Serial.begin(115200);
   // ⭐ ADD THIS: Give serial time to initialize
  delay(1000);

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
  setupPushButton(); 
  setupBatteryMonitor(); // Initialize battery ADC sensing

  // ── Connect to WiFi ─────────────────────────────────────────
  connectToWiFi();
 // Check if waking from deep sleep
    esp_sleep_wakeup_cause_t wakeup_cause = esp_sleep_get_wakeup_cause();
    if (wakeup_cause == ESP_SLEEP_WAKEUP_EXT0) {
        Serial.println("🔘 Woke up from deep sleep by button press");
        // Send immediate heartbeat to update status
        sendPowerStatusToServer(true);
    }
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
  server.on("/display/ready",  handleDisplayReady); // Show system ready screen
  server.on("/display/text",   handleDisplayText);  // Show custom text (?msg=...)
  server.on("/battery",        handleBatteryStatus); // Returns live battery % & voltage JSON
  
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


    // ── Reset WiFi endpoint: clears stored WiFi and reboots into Captive Portal ──
  server.on("/config/reset_wifi", []() {
    WiFiManager wm;
    wm.resetSettings();
    server.send(200, "text/plain", "WiFi credentials wiped. Rebooting into AP Setup Portal...");
    delay(1000);
    ESP.restart();
  });


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

  // ── Power status endpoint ──
server.on("/power/status", []() {
  String status = isESP32Powered() ? "on" : "sleeping";
  String json = "{\"power_state\":\"" + status + "\"}";
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
});

// ── Power on endpoint ──
server.on("/power/on", []() {
  powerOnESP32();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Power ON");
});

// ── Power off endpoint ──
server.on("/power/off", []() {
  // Note: This will trigger deep sleep, response may not reach client
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Powering OFF...");
  delay(100);
  powerOffESP32();
});

  // ── Start the HTTP server ──
  server.begin();

  // ── Power control endpoints ──
server.on("/power/sleep", HTTP_GET, []() {
  Serial.println("📴 Received sleep command from server");
  server.send(200, "text/plain", "Going to sleep...");
  // Small delay to send response before sleeping
  delay(500);
  powerOffESP32();
});

server.on("/power/wake", HTTP_GET, []() {
  Serial.println("📴 Received wake command from server");
  server.send(200, "text/plain", "Waking up...");
  powerOnESP32();
});

}

// ──────────────────────────────────────────────────────────────
// Check if button is held for 5 seconds to trigger WiFi reset
// ──────────────────────────────────────────────────────────────
unsigned long buttonPressStartTime = 0;
bool isHoldingButton = false;

void checkWiFiResetButton() {
  if (digitalRead(PUSH_BUTTON_PIN) == BUTTON_PRESSED) {
    if (!isHoldingButton) {
      isHoldingButton = true;
      buttonPressStartTime = millis();
    } else if (millis() - buttonPressStartTime > 5000) { // Held for 5 seconds
      Serial.println("🔄 Button held for 5s: Resetting WiFi...");
      updateDisplayState("Resetting WiFi", "Please Wait...");
      
      WiFiManager wm;
      wm.resetSettings(); // Clears saved WiFi credentials from flash
      
      delay(1000);
      ESP.restart(); // Reboots into 'MedSmart-Setup' captive portal
    }
  } else {
    isHoldingButton = false;
  }
}

// ──────────────────────────────────────────────────────────────
// Arduino loop() – runs continuously
// ──────────────────────────────────────────────────────────────
void loop() 
{
  handleTouch();            // Check if the physical touch button was pressed
  checkWiFiResetButton();   // 🔄 Check if button is held for 5s to reset WiFi
  handlePushButton();       // Normal short-press button handler
  server.handleClient();    // Process incoming HTTP requests

  // 1. WiFi watchdog – reconnect if disconnected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi lost. Reconnecting...");
    WiFi.disconnect();
    WiFi.reconnect();
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
  if (isOutOfStockBeeping) {
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
        int batteryPct = readBatteryPercentage();
        float batteryV = readBatteryVoltage();
        Serial.printf("🔋 Heartbeat Battery: %d%% (%.2fV)\n", batteryPct, batteryV);

        String jsonPayload = "{\"device_serial\":\"" + deviceSerial + 
                             "\",\"battery\":" + String(batteryPct) + 
                             ",\"rssi\":" + String(rssi) + 
                             ",\"ip\":\"" + deviceIP + 
                             "\",\"is_awake\":" + String(isESP32Powered() ? "true" : "false") + "}";
        
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