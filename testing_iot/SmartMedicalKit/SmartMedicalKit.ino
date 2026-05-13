// SmartMedicalKit.ino
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>      // ⚠️ Added for Heartbeat functionality
#include "dispenser_motor.h" 
#include "buzzer_control.h" 
#include <ArduinoJson.h>
#include "display_control.h" 
#include "secrets.h"

const char* ssid = SECRET_SSID; 
const char* password = SECRET_PASS;


const String backendUrl = "http://172.20.10.9:5000/device/heartbeat";
const String deviceSerial = "DISP-1"; // Must match the serial in your database

WebServer server(80);
const int ledPin = 18; 

// ⏱️ Timer variables for heartbeat
unsigned long lastHeartbeatTime = 0;
const unsigned long heartbeatInterval = 30000; // Send heartbeat every 30 seconds (30,000 ms)

void setupTouch();  // 声明外部触摸初始化函数
void handleTouch(); // 声明外部触摸处理函数


// --- NEW FUNCTION TO HANDLE THE DISPENSE LOGIC ---
void markDoseAsTaken(int adlogId, int prescriptionId) {
  HTTPClient http;
  String url = "http://172.20.10.9:5000/device/dispense_success";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("ngrok-skip-browser-warning", "true");
  
  String payload = "{\"adlog_id\":" + String(adlogId) + ",\"prescription_id\":" + String(prescriptionId) + "}";
  int httpCode = http.POST(payload);
  
  if(httpCode == 200) {
     Serial.println("✅ Database Updated: Medication marked as TAKEN and inventory deducted.");
  } else {
     Serial.println("❌ Failed to update database.");
  }
  http.end();
}

void checkAndDispenseDose() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = "http://172.20.10.9:5000/device/" + deviceSerial + "/pending_dose";
    
    http.begin(url);
    http.addHeader("ngrok-skip-browser-warning", "true");
    int httpCode = http.GET();
    
    if (httpCode == 200) {
      String payload = http.getString();
      
      // Parse the JSON response
      DynamicJsonDocument doc(1024);
      deserializeJson(doc, payload);
      
      if (doc["success"] == true && doc["has_pending"] == true) {
        int motorSlot = doc["data"]["motor_slot"];
        int adlogId = doc["data"]["adlog_id"];
        int prescriptionId = doc["data"]["prescription_id"];
        String medName = doc["data"]["medication_name"].as<String>();
        
        Serial.println("🚨 Pending Dose Found: " + medName);
        Serial.println("⚙️ Rotating Motor Slot: " + String(motorSlot));
        
        // 1. ROTATE THE CORRECT MOTOR
        if (motorSlot == 1) handleMotorForward();
        else if (motorSlot == 2) handleMotor2Forward();
        else if (motorSlot == 3) handleMotor3Forward();
        else Serial.println("Error: Invalid Motor Slot!");
        
        // 2. TELL BACKEND IT WAS DISPENSED
        markDoseAsTaken(adlogId, prescriptionId);
        
      } else {
        Serial.println("ℹ️ Button pressed, but no pending doses right now.");
        // Optional: Beep twice quickly to tell the patient nothing is due
        // handleBuzzerOn(); delay(100); handleBuzzerOff(); delay(100);
        // handleBuzzerOn(); delay(100); handleBuzzerOff();
      }
    } else {
      Serial.println("❌ Failed to connect to server. HTTP Code: " + String(httpCode));
    }
    http.end();
  }
}

void setup() {
  Serial.begin(115200);
  
  // Setup Hardware
  pinMode(ledPin, OUTPUT);
  setupStepper(); 
  setupBuzzer(); 
  setupDisplay(); // Initialize screen
  setupTouch();

  // Setup WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP()); 

  // --- LED Routes ---
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

  // --- Buzzer Routes ---
  server.on("/buzzer/on", handleBuzzerOn);
  server.on("/buzzer/off", handleBuzzerOff);

  // --- Display Routes ---
  server.on("/display/hello", handleDisplayHello);
  server.on("/display/clear", handleDisplayClear);
  server.on("/display/sv", handleDisplaySV); 
  
  // --- Motor 1 Routes ---
  server.on("/stepper/forward", handleMotorForward);
  server.on("/stepper/backward", handleMotorBackward);
  server.on("/stepper/90", handleMotor90);
  server.on("/stepper/180", handleMotor180);

  // --- Motor 2 Routes ---
  server.on("/stepper2/forward", handleMotor2Forward);
  server.on("/stepper2/backward", handleMotor2Backward);
  server.on("/stepper2/90", handleMotor290);
  server.on("/stepper2/180", handleMotor2180);

  // --- Motor 3 Routes ---
  server.on("/stepper3/forward", handleMotor3Forward);
  server.on("/stepper3/backward", handleMotor3Backward);
  server.on("/stepper3/90", handleMotor390);
  server.on("/stepper3/180", handleMotor3180);
  
  server.begin();
}

void loop() {

  handleTouch();
  // 1. Listen for incoming commands from Flutter app (LED, Buzzer, Motors)
  server.handleClient();

  // 2. ⚠️ Send Heartbeat to Flask Backend every 30 seconds
  if ((millis() - lastHeartbeatTime) > heartbeatInterval) {
    
    // Only try to send if we are actually connected to the internet
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      
      http.begin(backendUrl);
      http.addHeader("Content-Type", "application/json");


      // ⚠️ 1. 加上这行通行证，绕过 Ngrok 的拦截页面
      http.addHeader("ngrok-skip-browser-warning", "true"); 
      
      // ⚠️ 2. 告诉 ESP32 如果 Ngrok 强制把 http 换成 https，请自动跟随跳转
      http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

      // Replace 100 with real analogRead() logic if you wire up a battery sensor
      int batteryLevel = 100; 
      long rssi = WiFi.RSSI(); // Read WiFi signal strength

      // Construct the JSON payload
      String jsonPayload = "{\"device_serial\":\"" + deviceSerial + "\",\"battery\":" + String(batteryLevel) + ",\"rssi\":" + String(rssi) + "}";

      Serial.println("Sending Heartbeat: " + jsonPayload);
      
      // Fire the POST request
      int httpResponseCode = http.POST(jsonPayload);
      
      if (httpResponseCode > 0) {
        Serial.print("Heartbeat Sent Successfully. DB Updated. Response code: ");
        Serial.println(httpResponseCode);
      } else {
        Serial.print("Error sending heartbeat. Code: ");
        Serial.println(httpResponseCode);
      }
      
      http.end(); // Free up resources
    } else {
      Serial.println("WiFi Disconnected. Skipping heartbeat.");
    }
    
    lastHeartbeatTime = millis(); // Reset the timer
  }
}