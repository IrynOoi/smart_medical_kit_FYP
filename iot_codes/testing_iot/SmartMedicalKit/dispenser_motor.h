//dispenser_motor.h
#ifndef DISPENSER_MOTOR_H
#define DISPENSER_MOTOR_H

#include <Arduino.h>
#include <Stepper.h>
#include <WebServer.h>

extern WebServer server; 

void setupStepper();

// Motor 1 Functions
void handleMotorForward();
void handleMotorBackward(); 
void handleMotor90();       
void handleMotor180();      

// Motor 2 Functions
void handleMotor2Forward();
void handleMotor2Backward(); 
void handleMotor290();       
void handleMotor2180();      

// Motor 3 Functions (NEW)
void handleMotor3Forward();
void handleMotor3Backward(); 
void handleMotor390();       
void handleMotor3180();      

void rotateMotorHardware(int slot);
#endif