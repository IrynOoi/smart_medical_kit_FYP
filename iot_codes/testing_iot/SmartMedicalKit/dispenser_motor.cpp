// dispenser_motor.cpp
// This file implements control for three stepper motors used in a dispenser system.
// It defines motor pin assignments, initialization, and HTTP request handlers
// that rotate each motor by specific angles (90°, 180°, 360°) in both directions.
// The motors are powered off after each movement to save energy and prevent overheating.

#include "dispenser_motor.h"

// Number of steps for a full 360° rotation (depends on the stepper motor and driver)
const int stepsPerRevolution = 2048; 

// -------------------------------------------------------------------
// Motor 1 – Pin assignments (pins are connected to the driver module)
// Pins: 4, 16, 17, 5
// Note: The middle pins (16 and 17) have been swapped to correct the wiring order.
//       This ensures the motor rotates in the intended direction.
// -------------------------------------------------------------------
Stepper myStepper1(stepsPerRevolution, 4, 17, 16, 5);

// -------------------------------------------------------------------
// Motor 2 – Pins: 13, 12, 14, 27
// Middle pins (12 and 14) are swapped.
// -------------------------------------------------------------------
Stepper myStepper2(stepsPerRevolution, 13, 14, 12, 27);

// -------------------------------------------------------------------
// Motor 3 – Pins: 26, 25, 33, 32
// Middle pins (25 and 33) are swapped.
// -------------------------------------------------------------------
Stepper myStepper3(stepsPerRevolution, 26, 33, 25, 32);

// ========================================================
// 🛑 Motor power-off functions
// These functions set all four control pins of a motor to LOW,
// effectively cutting power to the driver and stopping current flow.
// They are placed early so they can be called from setupStepper().
// ========================================================
void disableMotor1() {
  digitalWrite(4, LOW);
  digitalWrite(17, LOW);
  digitalWrite(16, LOW);
  digitalWrite(5, LOW);
}

void disableMotor2() {
  digitalWrite(13, LOW);
  digitalWrite(14, LOW);
  digitalWrite(12, LOW);
  digitalWrite(27, LOW);
}

void disableMotor3() {
  digitalWrite(26, LOW);
  digitalWrite(33, LOW);
  digitalWrite(25, LOW);
  digitalWrite(32, LOW);
}

// ========================================================
// ⚙️ Initialization
// Called once during system startup (e.g., in setup()).
// Sets the rotation speed (RPM equivalent) for all motors,
// then powers them off to ensure they start in a known state.
// ========================================================
void setupStepper() {
  // Speed value determines the step delay; 15 is a moderate speed.
  myStepper1.setSpeed(15); 
  myStepper2.setSpeed(15); 
  myStepper3.setSpeed(15); 

  // Ensure all motors are powered off at boot.
  disableMotor1();
  disableMotor2();
  disableMotor3();
}

// =========================
// MOTOR 1 CONTROLS
// Each handler performs a specific movement and then disables the motor.
// After the movement, it sends a CORS-enabled HTTP response to the client.
// The 'server' object is assumed to be defined globally (e.g., from a web server library).
// =========================

// Rotate motor 1 forward by one full revolution (360°)
void handleMotorForward() {
  Serial.println("Motor 1 rotating 360 FORWARD...");
  myStepper1.step(stepsPerRevolution);   // positive step = forward direction
  disableMotor1();                       // cut power after movement
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 360 Forward & Powered Off");
}

// Rotate motor 1 backward by one full revolution (360°)
void handleMotorBackward() {
  Serial.println("Motor 1 rotating 360 BACKWARD...");
  myStepper1.step(-stepsPerRevolution);  // negative step = backward direction
  disableMotor1();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 360 Backward & Powered Off");
}

// Rotate motor 1 forward by 90° (2048 steps = 360°, so 90° = 2048/4 = 512 steps)
void handleMotor90() {
  Serial.println("Motor 1 rotating 90 degrees...");
  myStepper1.step(512);   // 90° = 512 steps
  disableMotor1();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 90 Degrees & Powered Off");
}

// Rotate motor 1 forward by 180° (2048/2 = 1024 steps)
void handleMotor180() {
  Serial.println("Motor 1 rotating 180 degrees...");
  myStepper1.step(1024);  // 180° = 1024 steps
  disableMotor1();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 180 Degrees & Powered Off");
}

// =========================
// MOTOR 2 CONTROLS
// Identical to motor 1, but using motor 2's object and disable function.
// =========================
void handleMotor2Forward() {
  Serial.println("Motor 2 rotating 360 FORWARD...");
  myStepper2.step(stepsPerRevolution);
  disableMotor2();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 360 Forward & Powered Off");
}

void handleMotor2Backward() {
  Serial.println("Motor 2 rotating 360 BACKWARD...");
  myStepper2.step(-stepsPerRevolution);
  disableMotor2();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 360 Backward & Powered Off");
}

void handleMotor290() {
  Serial.println("Motor 2 rotating 90 degrees...");
  myStepper2.step(512);
  disableMotor2();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 90 Degrees & Powered Off");
}

void handleMotor2180() {
  Serial.println("Motor 2 rotating 180 degrees...");
  myStepper2.step(1024);
  disableMotor2();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 2 Rotated 180 Degrees & Powered Off");
}

// =========================
// MOTOR 3 CONTROLS
// Identical to motor 1 and 2, but using motor 3's object and disable function.
// =========================
void handleMotor3Forward() {
  Serial.println("Motor 3 rotating 360 FORWARD...");
  myStepper3.step(stepsPerRevolution);
  disableMotor3();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 360 Forward & Powered Off");
}

void handleMotor3Backward() {
  Serial.println("Motor 3 rotating 360 BACKWARD...");
  myStepper3.step(-stepsPerRevolution);
  disableMotor3();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 360 Backward & Powered Off");
}

void handleMotor390() {
  Serial.println("Motor 3 rotating 90 degrees...");
  myStepper3.step(512);
  disableMotor3();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 90 Degrees & Powered Off");
}

// -------------------------------------------------------------------
// Hardware rotation function – rotates a specific motor by one full turn
// This is useful for dispenser logic where a slot number is provided.
// It does not send an HTTP response; it only performs the movement.
// -------------------------------------------------------------------
void rotateMotorHardware(int slot) {
  if (slot == 1) {
    myStepper1.step(stepsPerRevolution);
    disableMotor1();
  } else if (slot == 2) {
    myStepper2.step(stepsPerRevolution);
    disableMotor2();
  } else if (slot == 3) {
    myStepper3.step(stepsPerRevolution);
    disableMotor3();
  }
}

// 180° rotation handler for motor 3 (placed after rotateMotorHardware)
void handleMotor3180() {
  Serial.println("Motor 3 rotating 180 degrees...");
  myStepper3.step(1024);
  disableMotor3();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 180 Degrees & Powered Off");
}