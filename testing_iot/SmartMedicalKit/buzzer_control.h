//buzzer_control.h
#ifndef BUZZER_CONTROL_H
#define BUZZER_CONTROL_H

#include <Arduino.h>
#include <WebServer.h>

extern WebServer server; // Reference the server from your main file

void setupBuzzer();
void handleBuzzerOn();
void handleBuzzerOff();

#endif