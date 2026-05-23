// SmartMedicalKit.ino
#include <WiFi.h>
#include <WebServer.h>
#include "dispenser_motor.h" 
#include "buzzer_control.h" 
#include "display_control.h" // ⚠️ Added new display header
#include "secrets.h"

const char* ssid = SECRET_SSID; 
const char* password = SECRET_PASS;
WebServer server(80);
const int ledPin = 18; 

void setup() {
  Serial.begin(115200);
  
  // Setup Hardware
  pinMode(ledPin, OUTPUT);
  setupStepper(); 
  setupBuzzer(); 
  setupDisplay(); // ⚠️ Initialize screen

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
  server.on("/display/sv", handleDisplaySV); // ⚠️ ADD THIS LINE
  
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
  server.handleClient();
}