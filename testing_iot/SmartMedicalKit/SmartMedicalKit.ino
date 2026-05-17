// SmartMedicalKit.ino
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>      
#include "dispenser_motor.h" 
#include "buzzer_control.h" 
#include <ArduinoJson.h>
#include "display_control.h" 

// NOTE: No secrets.h or hardcoded passwords here!

const String backendUrl = "http://172.20.10.9:5000/device/heartbeat";
const String deviceSerial = "DISP-1"; 

WebServer server(80);
const int ledPin = 18; 

// ⏱️ Timers
unsigned long lastHeartbeatTime = 0;
const unsigned long heartbeatInterval = 30000; 

unsigned long lastDoseCheckTime = 0;
const unsigned long doseCheckInterval = 10000; // Automatically check every 10 seconds

unsigned long lastBeepTime = 0;
bool currentBuzzerState = false;

// 🧠 State Machine Variables
bool isDoseWaiting = false;
int pendingMotorSlot = 0;
int pendingAdlogId = 0;
int pendingPrescriptionId = 0;
String pendingMedName = "";

void setupTouch();  
void handleTouch(); 

// ==========================================
// --- SMART CONFIG ROUTINE (You missed this part!) ---
// ==========================================
void connectToWiFi() {
  WiFi.mode(WIFI_AP_STA); 
  WiFi.begin(); // Automatically tries the last saved WiFi network

  Serial.print("Connecting to saved WiFi...");
  int retries = 0;
  
  // Wait up to 10 seconds to see if it connects to the old network
  while (WiFi.status() != WL_CONNECTED && retries < 20) {
    delay(500);
    Serial.print(".");
    retries++;
  }

  // If it failed to connect, trigger SmartConfig
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nNo saved WiFi found. Entering SmartConfig Mode...");
    
    // Update OLED to tell the user to use the phone app
    updateDisplayState("Need WiFi!", "Use Phone App"); 
    
    WiFi.beginSmartConfig();

    // Wait until it receives credentials from the phone
    while (!WiFi.smartConfigDone()) {
      delay(500);
      Serial.print("*");
    }

    Serial.println("\nSmartConfig details received.");
    Serial.println("Waiting for WiFi connection...");
    updateDisplayState("Connecting...", "Please wait");

    // Wait until it actually connects to the router
    while (WiFi.status() != WL_CONNECTED) {
      delay(500);
      Serial.print(".");
    }
  }

  // Success!
  Serial.println("\nWiFi Connected!");
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  
  updateDisplayState("MedSmart", "Ready!");
}


// --- UPDATED LOGIC ---
void markDoseAsTaken(int adlogId, int prescriptionId) {
  HTTPClient http;
  String url = "http://172.20.10.9:5000/device/dispense_success";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("ngrok-skip-browser-warning", "true");
  
  String payload = "{\"adlog_id\":" + String(adlogId) + ",\"prescription_id\":" + String(prescriptionId) + "}";
  int httpCode = http.POST(payload);
  
  if(httpCode == 200) {
     Serial.println("✅ Database Updated: Medication marked as TAKEN.");
  } else {
     Serial.println("❌ Failed to update database.");
  }
  http.end();
}

// 1. This function automatically polls the server every 10 seconds
void checkForPendingDose() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = "http://172.20.10.9:5000/device/" + deviceSerial + "/pending_dose";
    
    http.begin(url);
    http.addHeader("ngrok-skip-browser-warning", "true");
    int httpCode = http.GET();
    
    if (httpCode == 200) {
      String payload = http.getString();
      DynamicJsonDocument doc(1024);
      deserializeJson(doc, payload);
      
      if (doc["success"] == true && doc["has_pending"] == true) {
        pendingMotorSlot = doc["data"]["motor_slot"];
        pendingAdlogId = doc["data"]["adlog_id"];
        pendingPrescriptionId = doc["data"]["prescription_id"];
        pendingMedName = doc["data"]["medication_name"].as<String>();
        
        Serial.println("🚨 Dispense Time Arrived for: " + pendingMedName);
        isDoseWaiting = true;
        updateDisplayState("Medicine Due!", pendingMedName);
      }
    }
    http.end();
  }
}

// 2. This function fires ONLY when the user touches the button while a dose is waiting
void executeDispense() {
  isDoseWaiting = false; 
  triggerBuzzerHardware(false);
  
  Serial.println("⚙️ Dispensing...");
  updateDisplayState("Dispensing...", pendingMedName);
  
  rotateMotorHardware(pendingMotorSlot);
  markDoseAsTaken(pendingAdlogId, pendingPrescriptionId);
  
  updateDisplayState("Finished!", "Take Meds");
  delay(4000); 
  handleDisplayClear();
}


void setup() {
  Serial.begin(115200);
  
  pinMode(ledPin, OUTPUT);
  setupStepper(); 
  setupBuzzer(); 
  setupDisplay(); 
  setupTouch();

  // Call the SmartConfig setup routine
  connectToWiFi();

  // --- API Routes ---
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

  server.on("/buzzer/on", handleBuzzerOn);
  server.on("/buzzer/off", handleBuzzerOff);

  server.on("/display/hello", handleDisplayHello);
  server.on("/display/clear", handleDisplayClear);
  server.on("/display/sv", handleDisplaySV); 
  
  server.on("/stepper/forward", handleMotorForward);
  server.on("/stepper/backward", handleMotorBackward);
  server.on("/stepper/90", handleMotor90);
  server.on("/stepper/180", handleMotor180);

  server.on("/stepper2/forward", handleMotor2Forward);
  server.on("/stepper2/backward", handleMotor2Backward);
  server.on("/stepper2/90", handleMotor290);
  server.on("/stepper2/180", handleMotor2180);

  server.on("/stepper3/forward", handleMotor3Forward);
  server.on("/stepper3/backward", handleMotor3Backward);
  server.on("/stepper3/90", handleMotor390);
  server.on("/stepper3/180", handleMotor3180);
  
  server.begin();
}

void loop() {
  handleTouch();
  server.handleClient();

  // 1. AUTOPILOT CHECK
  if (!isDoseWaiting && (millis() - lastDoseCheckTime > doseCheckInterval)) {
    checkForPendingDose();
    lastDoseCheckTime = millis();
  }

  // 2. AUTOPILOT BEEP
  if (isDoseWaiting && (millis() - lastBeepTime > 1000)) {
    currentBuzzerState = !currentBuzzerState; 
    triggerBuzzerHardware(currentBuzzerState);
    lastBeepTime = millis();
  }

  // 3. Heartbeat to Flask Backend
  if ((millis() - lastHeartbeatTime) > heartbeatInterval) {
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      http.begin(backendUrl);
      http.addHeader("Content-Type", "application/json");
      http.addHeader("ngrok-skip-browser-warning", "true"); 
      http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

      int batteryLevel = 100; 
      long rssi = WiFi.RSSI(); 

      String jsonPayload = "{\"device_serial\":\"" + deviceSerial + "\",\"battery\":" + String(batteryLevel) + ",\"rssi\":" + String(rssi) + "}";
      
      int httpResponseCode = http.POST(jsonPayload);
      if (httpResponseCode > 0) {
        Serial.println("Heartbeat Sent Successfully.");
      } else {
        Serial.print("Error sending heartbeat. Code: ");
        Serial.println(httpResponseCode);
      }
      http.end(); 
    }
    lastHeartbeatTime = millis();
  }
}