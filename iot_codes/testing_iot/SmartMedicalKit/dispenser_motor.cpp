// dispenser_motor.cpp
#include "dispenser_motor.h"

const int stepsPerRevolution = 2048; 

// Motor 1 (Pins: 4, 16, 17, 5 -> Middle swapped to 17, 16)
Stepper myStepper1(stepsPerRevolution, 4, 17, 16, 5);

// Motor 2 (Pins: 13, 12, 14, 27 -> Middle swapped to 14, 12)
Stepper myStepper2(stepsPerRevolution, 13, 14, 12, 27);

// Motor 3 (Pins: 26, 25, 33, 32 -> Middle swapped to 33, 25)
Stepper myStepper3(stepsPerRevolution, 26, 33, 25, 32);

// ========================================================
// 🛑 断电函数（挪到了最上面，让编译器先认识它们）
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
// ⚙️ 初始化
// ========================================================
void setupStepper() {
  myStepper1.setSpeed(15); 
  myStepper2.setSpeed(15); 
  myStepper3.setSpeed(15); 

  // ⚠️ 现在可以正常调用了，编译器已经读到上面的定义了
  disableMotor1();
  disableMotor2();
  disableMotor3();
}

// =========================
// MOTOR 1 CONTROLS
// =========================
void handleMotorForward() {
  Serial.println("Motor 1 rotating 360 FORWARD...");
  myStepper1.step(stepsPerRevolution); 
  disableMotor1(); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 360 Forward & Powered Off");
}

void handleMotorBackward() {
  Serial.println("Motor 1 rotating 360 BACKWARD...");
  myStepper1.step(-stepsPerRevolution); 
  disableMotor1(); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 360 Backward & Powered Off");
}

void handleMotor90() {
  Serial.println("Motor 1 rotating 90 degrees...");
  myStepper1.step(512); 
  disableMotor1(); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 90 Degrees & Powered Off");
}

void handleMotor180() {
  Serial.println("Motor 1 rotating 180 degrees...");
  myStepper1.step(1024); 
  disableMotor1(); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 1 Rotated 180 Degrees & Powered Off");
}

// =========================
// MOTOR 2 CONTROLS
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
// MOTOR 3 CONTROLS (NEW)
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

void handleMotor3180() {
  Serial.println("Motor 3 rotating 180 degrees...");
  myStepper3.step(1024); 
  disableMotor3(); 
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Motor 3 Rotated 180 Degrees & Powered Off");
}