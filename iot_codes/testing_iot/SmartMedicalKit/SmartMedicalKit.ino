// SmartMedicalKit.ino

#include <WiFi.h>
#include <WebServer.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>      
#include "dispenser_motor.h" 
#include "buzzer_control.h" 
#include <ArduinoJson.h>
#include "display_control.h" 
#include "secrets.h"
#include <Preferences.h>

Preferences prefs;


String serverBase = "https://reluctant-scrambled-badge.ngrok-free.dev";

const String deviceSerial = "DISP-1"; 

WebServer server(80);
const int ledPin = 18; 

// ⏱️ Timers
unsigned long lastHeartbeatTime = 0;
const unsigned long heartbeatInterval = 30000; 

unsigned long lastDoseCheckTime = 0;
const unsigned long doseCheckInterval = 10000; 

// ⏳ Normal dose timeout
unsigned long doseStartTime = 0;
const unsigned long doseTimeout = 10000;

// 🧠 Normal dose state machine
bool isDoseWaiting = false;
int pendingMotorSlot = 0;
int pendingAdlogId = 0;
int pendingPrescriptionId = 0;
String pendingMedName = "";

// 🚨 Out-of-stock alarm state
bool isOutOfStockBeeping = false;
unsigned long outOfStockStartTime = 0;
const unsigned long outOfStockTimeout = 10000; 
unsigned long lastBuzzerToggleTime = 0;
bool outOfStockBuzzerState = false;

void setupTouch();  
void handleTouch(); 

// ─────────────────────────────────────────────
// Helper: build full URL from path
// ─────────────────────────────────────────────
String buildURL(String path) {
  return serverBase + path;
}

// ─────────────────────────────────────────────
// WiFi
// ─────────────────────────────────────────────
void connectToWiFi() {
  WiFi.disconnect(true);
  delay(1000); 
  WiFi.mode(WIFI_STA); 
  
  Serial.print("Connecting to WiFi: ");
  Serial.println(SECRET_SSID);
  updateDisplayState("Connecting...", "WiFi");
  
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

// ─────────────────────────────────────────────
// HTTP Helpers
// ─────────────────────────────────────────────
void addCommonHeaders(HTTPClient &http) {
  http.addHeader("Content-Type", "application/json");
  http.addHeader("ngrok-skip-browser-warning", "true");
  http.setConnectTimeout(10000);
  http.setTimeout(10000);
  http.addHeader("Connection", "close");
}

// ─────────────────────────────────────────────
// Mark dose as TAKEN
// ─────────────────────────────────────────────
void markDoseAsTaken(int adlogId, int prescriptionId) {
  HTTPClient http;
  String url = buildURL("/device/dispense_success");
  
  WiFiClientSecure secureClient;
  secureClient.setInsecure(); // Bypass SSL verification

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

// ─────────────────────────────────────────────
// Mark dose as MISSED
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// Poll server for pending dose
// ─────────────────────────────────────────────
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
    DynamicJsonDocument doc(1024);
    deserializeJson(doc, payload);

    if (doc["success"] == true && doc["has_pending"] == true) {

      // 💡 Out of stock?
      if (doc["is_empty"] == true) { 
        pendingMedName = doc["data"]["medication_name"].as<String>();
        String slotNum = doc["data"]["motor_slot"].as<String>();
        pendingAdlogId = doc["data"]["adlog_id"];
        
        Serial.println("⚠️ Out of stock: " + pendingMedName + " (Slot " + slotNum + ")");
        updateDisplayState("Slot " + slotNum + " Empty", "Refill " + pendingMedName);
        
        isOutOfStockBeeping = true;
        outOfStockStartTime = millis();
        lastBuzzerToggleTime = millis();
        outOfStockBuzzerState = true;
        triggerBuzzerHardware(true); 
        
        http.end();
        return;
      }

      // ⚙️ Normal dispense
      pendingMotorSlot     = doc["data"]["motor_slot"];
      pendingAdlogId       = doc["data"]["adlog_id"];
      pendingPrescriptionId= doc["data"]["prescription_id"];
      pendingMedName       = doc["data"]["medication_name"].as<String>();
      
      Serial.println("🚨 Dose due: " + pendingMedName);
      isDoseWaiting = true;
      doseStartTime = millis(); 
      triggerBuzzerHardware(true);
      updateDisplayState("Medicine Due!", pendingMedName);
    }
  } else {
    Serial.print("⚠️ checkForPendingDose HTTP code: ");
    Serial.println(httpCode);
  }
  http.end();
}

// ─────────────────────────────────────────────
// Dispense (touch button handler)
// ─────────────────────────────────────────────
void executeDispense() {
  if (isOutOfStockBeeping) {
    Serial.println("🛑 User dismissed out-of-stock alarm.");
    isOutOfStockBeeping = false;
    triggerBuzzerHardware(false);
    if (WiFi.status() == WL_CONNECTED) markDoseAsMissed(pendingAdlogId); 
    updateDisplayState("MedSmart System", "Ready!"); 
    return;
  }

  if (isDoseWaiting) {
    isDoseWaiting = false; 
    triggerBuzzerHardware(false);
    
    Serial.println("⚙️ Dispensing: " + pendingMedName);
    updateDisplayState("Dispensing...", pendingMedName);
    
    rotateMotorHardware(pendingMotorSlot);
    markDoseAsTaken(pendingAdlogId, pendingPrescriptionId);
    
    updateDisplayState("Finished!", "Take Meds");
    delay(4000); 
    updateDisplayState("MedSmart System", "Ready!"); 
  }
}

// ─────────────────────────────────────────────
// Setup
// ─────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // Load saved ngrok URL from flash (if any)
  prefs.begin("medsmart", false);
  String savedURL = prefs.getString("server_url", "");
  if (savedURL.length() > 0) {
    serverBase = savedURL;
    Serial.println("📡 Loaded server URL from flash: " + serverBase);
  }
  prefs.end();
  
  pinMode(ledPin, OUTPUT);
  setupStepper(); 
  setupBuzzer(); 
  setupDisplay(); 
  setupTouch();

  connectToWiFi();

  // ── REST API routes ──────────────────────────
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

  server.on("/buzzer/on",      handleBuzzerOn);
  server.on("/buzzer/off",     handleBuzzerOff);
  server.on("/display/hello",  handleDisplayHello);
  server.on("/display/clear",  handleDisplayClear);
  server.on("/display/sv",     handleDisplaySV); 
  
  server.on("/stepper/forward",   handleMotorForward);
  server.on("/stepper/backward",  handleMotorBackward);
  server.on("/stepper/90",        handleMotor90);
  server.on("/stepper/180",       handleMotor180);

  server.on("/stepper2/forward",  handleMotor2Forward);
  server.on("/stepper2/backward", handleMotor2Backward);
  server.on("/stepper2/90",       handleMotor290);
  server.on("/stepper2/180",      handleMotor2180);

  server.on("/stepper3/forward",  handleMotor3Forward);
  server.on("/stepper3/backward", handleMotor3Backward);
  server.on("/stepper3/90",       handleMotor390);
  server.on("/stepper3/180",      handleMotor3180);


server.on("/retake", HTTP_GET, []() {
    if (server.hasArg("adlog_id") && server.hasArg("prescription_id") && server.hasArg("slot")) {
        int adlogId = server.arg("adlog_id").toInt();
        int prescriptionId = server.arg("prescription_id").toInt();
        int motorSlot = server.arg("slot").toInt();
        String medName = server.hasArg("med_name") ? server.arg("med_name") : "Medicine";

        // Cancel any ongoing out‑of‑stock or normal waiting
        isOutOfStockBeeping = false;
        triggerBuzzerHardware(false);

        // Set the device into dose‑waiting mode
        isDoseWaiting = true;
        pendingMotorSlot = motorSlot;
        pendingAdlogId = adlogId;
        pendingPrescriptionId = prescriptionId;
        pendingMedName = medName;
        doseStartTime = millis();

        triggerBuzzerHardware(true);
        updateDisplayState("Medicine Due!", pendingMedName);

        server.send(200, "text/plain", "Retake started");
    } else {
        server.send(400, "text/plain", "Missing parameters: adlog_id, prescription_id, slot");
    }
});

  // 🔧 Update server URL without reflashing
  // Usage: http://<esp32-ip>/config/seturl?url=https://xxxx.ngrok-free.app
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

  // 🔍 Check current config
  server.on("/config/status", []() {
    String json = "{\"server_url\":\"" + serverBase + "\",\"device_serial\":\"" + deviceSerial + "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
    server.send(200, "application/json", json);
  });

  server.begin();
  Serial.println("🚀 HTTP server started");
}

// ─────────────────────────────────────────────
// Loop
// ─────────────────────────────────────────────
void loop() {
  handleTouch();
  server.handleClient();

  // 1. WiFi watchdog
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi lost. Reconnecting...");
    WiFi.disconnect();
    WiFi.begin(SECRET_SSID, SECRET_PASS); 
    delay(2000); 
  }

  // 2. Poll for pending dose
  if (WiFi.status() == WL_CONNECTED) {
    if (!isDoseWaiting && !isOutOfStockBeeping && (millis() - lastDoseCheckTime > doseCheckInterval)) {
      checkForPendingDose();
      lastDoseCheckTime = millis();
    }
  }

  // 3A. Out-of-stock beeping pattern
  if (isOutOfStockBeeping) {
    if (millis() - outOfStockStartTime > outOfStockTimeout) {
      isOutOfStockBeeping = false;
      triggerBuzzerHardware(false);
      Serial.println("🛑 Out-of-stock timeout. Marking as missed.");
      if (WiFi.status() == WL_CONNECTED) markDoseAsMissed(pendingAdlogId); 
      updateDisplayState("MedSmart System", "Ready!");
    } else {
      if (millis() - lastBuzzerToggleTime > 500) {
        outOfStockBuzzerState = !outOfStockBuzzerState;
        triggerBuzzerHardware(outOfStockBuzzerState);
        lastBuzzerToggleTime = millis();
      }
    }
  }

  // 3B. Normal dose timeout
  if (isDoseWaiting) {
    if (millis() - doseStartTime > doseTimeout) {
      Serial.println("⏰ Dose timeout — marked as missed.");
      isDoseWaiting = false; 
      triggerBuzzerHardware(false); 
      updateDisplayState("Missed Dose", pendingMedName);
      if (WiFi.status() == WL_CONNECTED) markDoseAsMissed(pendingAdlogId); 
      delay(4000);
      updateDisplayState("MedSmart System", "Ready!"); 
    }
  }

  // 4. Heartbeat
  if (millis() - lastHeartbeatTime > heartbeatInterval) {
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = buildURL("/device/heartbeat");

      Serial.println("💓 Sending heartbeat to: " + url);

      // FIX: Use WiFiClientSecure for HTTPS connections
      WiFiClientSecure secureClient;
      secureClient.setInsecure(); // Bypass strict certificate validation for ngrok

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