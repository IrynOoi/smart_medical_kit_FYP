//display_control.h
#ifndef DISPLAY_CONTROL_H
#define DISPLAY_CONTROL_H

#include <Arduino.h>
#include <WebServer.h>

extern WebServer server; 

void setupDisplay();
void handleDisplayHello();
void handleDisplayClear();
void handleDisplaySV();
void updateDisplayState(String title, String subtitle);

#endif