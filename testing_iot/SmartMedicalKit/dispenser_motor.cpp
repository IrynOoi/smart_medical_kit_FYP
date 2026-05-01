// dispenser_motor.cpp
#include "dispenser_motor.h"

const int stepsPerRevolution = 2048; 

// Motor 1 (Pins: 4, 16, 17, 5 -> Middle swapped to 17, 16)
Stepper myStepper1(stepsPerRevolution, 4, 17, 16, 5);

// Motor 2 (Pins: 13, 12, 14, 27 -> Middle swapped to 14, 12)
Stepper myStepper2(stepsPerRevolution, 13, 14, 12, 27);

// Motor 3 (Pins: 26, 25, 33, 32 -> Middle swapped to 33, 25)
Stepper myStepper3(stepsPerRevolution, 26, 33, 25, 32);

void setupStepper() {
  myStepper1.setSpeed(15); 
  myStepper2.setSpeed(15); 
  myStepper3.setSpeed(15); 
}

// =========================
// MOTOR 1 CONTROLS
// =========================
void handleMotorForward() {
  Serial.println("Motor 1 rotating 360 FORWARD...");
  myStepper1.step(stepsPerRevolution); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 360 Forward");
}

void handleMotorBackward() {
  Serial.println("Motor 1 rotating 360 BACKWARD...");
  myStepper1.step(-stepsPerRevolution); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 360 Backward");
}

void handleMotor90() {
  Serial.println("Motor 1 rotating 90 degrees...");
  myStepper1.step(512); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 90 Degrees");
}

void handleMotor180() {
  Serial.println("Motor 1 rotating 180 degrees...");
  myStepper1.step(1024); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 180 Degrees");
}

// =========================
// MOTOR 2 CONTROLS
// =========================
void handleMotor2Forward() {
  Serial.println("Motor 2 rotating 360 FORWARD...");
  myStepper2.step(stepsPerRevolution); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 360 Forward");
}

void handleMotor2Backward() {
  Serial.println("Motor 2 rotating 360 BACKWARD...");
  myStepper2.step(-stepsPerRevolution); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 360 Backward");
}

void handleMotor290() {
  Serial.println("Motor 2 rotating 90 degrees...");
  myStepper2.step(512); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 90 Degrees");
}

void handleMotor2180() {
  Serial.println("Motor 2 rotating 180 degrees...");
  myStepper2.step(1024); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 180 Degrees");
}

// =========================
// MOTOR 3 CONTROLS (NEW)
// =========================
void handleMotor3Forward() {
  Serial.println("Motor 3 rotating 360 FORWARD...");
  myStepper3.step(stepsPerRevolution); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 360 Forward");
}

void handleMotor3Backward() {
  Serial.println("Motor 3 rotating 360 BACKWARD...");
  myStepper3.step(-stepsPerRevolution); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 360 Backward");
}

void handleMotor390() {
  Serial.println("Motor 3 rotating 90 degrees...");
  myStepper3.step(512); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 90 Degrees");
}

void handleMotor3180() {
  Serial.println("Motor 3 rotating 180 degrees...");
  myStepper3.step(1024); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 180 Degrees");
}