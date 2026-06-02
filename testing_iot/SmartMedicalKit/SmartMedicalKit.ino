// SmartMedicalKit.ino
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>      
#include "dispenser_motor.h" 
#include "buzzer_control.h" 
#include <ArduinoJson.h>
// #include <ESPmDNS.h>
#include "display_control.h" 
#include <Preferences.h>

Preferences prefs;
String serverIP = "192.168.0.7"; 

// String url = "http://" + serverIP + ":5000/device/heartbeat";
const String deviceSerial = "DISP-1"; 

WebServer server(80);
const int ledPin = 18; 

// ⏱️ Timers
unsigned long lastHeartbeatTime = 0;
const unsigned long heartbeatInterval = 30000; 

unsigned long lastDoseCheckTime = 0;
const unsigned long doseCheckInterval = 10000; 

unsigned long lastBeepTime = 0;
bool currentBuzzerState = false;

// ⏳ 正常出药：超时倒计时器
unsigned long doseStartTime = 0;
const unsigned long doseTimeout = 30000; // 30,000 ms = 30 秒 (如需2分钟可改为 120000)

// 🧠 正常出药 State Machine Variables
bool isDoseWaiting = false;
int pendingMotorSlot = 0;
int pendingAdlogId = 0;
int pendingPrescriptionId = 0;
String pendingMedName = "";

// 🚨 新增：缺药 (Out of Stock) 警报状态变量
bool isOutOfStockBeeping = false;
unsigned long outOfStockStartTime = 0;
const unsigned long outOfStockTimeout = 30000; // 缺药警报响 30 秒
unsigned long lastBuzzerToggleTime = 0;
bool outOfStockBuzzerState = false;

void setupTouch();  
void handleTouch(); 

// --- SMART CONFIG ROUTINE ---
void connectToWiFi() {
  // 1. Clear any existing configuration to ensure a fresh start
  WiFi.disconnect(true);
  delay(1000); // Allow the Wi-Fi hardware to reset
  
  WiFi.mode(WIFI_AP_STA); 
  WiFi.begin(); 

  Serial.print("Connecting to saved WiFi...");
  int retries = 0;
  // Increase retries slightly to allow for slower router handshakes
  while (WiFi.status() != WL_CONNECTED && retries < 30) {
    delay(500);
    Serial.print(".");
    retries++;
  }

  // 2. If connection fails, enter SmartConfig
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nNo saved WiFi found or connection failed.");
    Serial.println("Entering SmartConfig Mode...");
    updateDisplayState("Need WiFi!", "Use ESP-Touch App"); 
    
    // Ensure the SmartConfig process starts fresh
    WiFi.beginSmartConfig();
    
    Serial.println("Waiting for SmartConfig packets...");
    while (!WiFi.smartConfigDone()) {
      delay(500);
      Serial.print("*");
    }

    Serial.println("\nSmartConfig packet received.");
    Serial.println("Waiting for WiFi connection...");
    updateDisplayState("Connecting...", "Please wait");

    // Wait for the actual connection to complete
    int connectionTimeout = 0;
    while (WiFi.status() != WL_CONNECTED && connectionTimeout < 40) {
      delay(500);
      Serial.print(".");
      connectionTimeout++;
    }
  }

  // 3. Final validation
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    updateDisplayState("MedSmart System", "Ready!");
  } else {
    Serial.println("\nWiFi Connection Failed. Please restart device.");
    updateDisplayState("Conn. Failed", "Restarting...");
    delay(2000);
    ESP.restart(); // Force restart to try again
  }
}

// --- UPDATED LOGIC ---
void markDoseAsTaken(int adlogId, int prescriptionId) {
  HTTPClient http;
  String url = "http://" + serverIP + ":5000/device/dispense_success";
  
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

// 🚨 通知后端记录 Missed Dose 的函数
void markDoseAsMissed(int adlogId) {
  HTTPClient http;
  String url = "http://" + serverIP + ":5000/device/dispense_missed";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("ngrok-skip-browser-warning", "true");
  
  String payload = "{\"adlog_id\":" + String(adlogId) + "}";
  int httpCode = http.POST(payload);
  
  if(httpCode == 200) {
     Serial.println("⚠️ Database Updated: Medication marked as MISSED.");
  } else {
     Serial.println("❌ Failed to update missed status.");
  }
  http.end();
}

// 1. This function automatically polls the server every 10 seconds
void checkForPendingDose() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = "http://" + serverIP + ":5000/device/" + deviceSerial + "/pending_dose";
    
    http.begin(url);
    http.addHeader("ngrok-skip-browser-warning", "true");
    int httpCode = http.GET();
    
    if (httpCode == 200) {
      String payload = http.getString();
      DynamicJsonDocument doc(1024);
      deserializeJson(doc, payload);

      if (doc["success"] == true && doc["has_pending"] == true) {
        
        // 💡 1. 优先检查：是否缺药 (Out of Stock)
        if (doc["is_empty"] == true) { 
          pendingMedName = doc["data"]["medication_name"].as<String>();
          String slotNum = doc["data"]["motor_slot"].as<String>();
          pendingAdlogId = doc["data"]["adlog_id"]; // 必须抓取，用于记录 Missed
          
          Serial.println("⚠️ 缺药警告: " + pendingMedName + " (Slot " + slotNum + ")");
          updateDisplayState("Slot " + slotNum + " Empty", "Refill " + pendingMedName);
          
          // 🚀 启动缺药时的断断续续警报状态
          isOutOfStockBeeping = true;
          outOfStockStartTime = millis();
          lastBuzzerToggleTime = millis();
          outOfStockBuzzerState = true;
          triggerBuzzerHardware(true); 
          
          return; // 🛑 核心：直接 return，阻止执行正常出药的响铃逻辑
        }

        // ⚙️ 2. 正常出药逻辑 (库存充足)
        pendingMotorSlot = doc["data"]["motor_slot"];
        pendingAdlogId = doc["data"]["adlog_id"];
        pendingPrescriptionId = doc["data"]["prescription_id"];
        pendingMedName = doc["data"]["medication_name"].as<String>();
        
        Serial.println("🚨 Dispense Time Arrived for: " + pendingMedName);
        isDoseWaiting = true;

        triggerBuzzerHardware(true); // 正常出药是长鸣
        
        // ⏳ 记录开始响铃的准确时间
        doseStartTime = millis(); 
        
        updateDisplayState("Medicine Due!", pendingMedName);
      }
    }
    http.end();
  }
}

// 2. This function fires ONLY when the user touches the button
void executeDispense() {
  // 💡 如果系统正在进行“缺药警报”，按下 Touch 按钮只是为了关掉警报
  if (isOutOfStockBeeping) {
    Serial.println("🛑 User dismissed out-of-stock alarm.");
    isOutOfStockBeeping = false;
    triggerBuzzerHardware(false);
    
    if (WiFi.status() == WL_CONNECTED) {
      markDoseAsMissed(pendingAdlogId); 
    }
    
    updateDisplayState("MedSmart System", "Ready!"); 
    return; // 结束函数，不要去转动电机
  }

  // ⚙️ 正常的出药逻辑
  if (isDoseWaiting) {
    isDoseWaiting = false; 
    triggerBuzzerHardware(false);
    
    Serial.println("⚙️ Dispensing...");
    updateDisplayState("Dispensing...", pendingMedName);
    
    rotateMotorHardware(pendingMotorSlot);
    markDoseAsTaken(pendingAdlogId, pendingPrescriptionId);
    
    updateDisplayState("Finished!", "Take Meds");
    delay(4000); 
    
    updateDisplayState("MedSmart System", "Ready!"); 
  }
}

void setup() {
  Serial.begin(115200);

  prefs.begin("medsmart", false);
  serverIP = prefs.getString("server_ip", "192.168.0.7");
  prefs.end();
  
  pinMode(ledPin, OUTPUT);
  setupStepper(); 
  setupBuzzer(); 
  setupDisplay(); 
  setupTouch();

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

  server.on("/config/setip", []() {
  if (server.hasArg("ip")) {
    String newIP = server.arg("ip");
    prefs.begin("medsmart", false);
    prefs.putString("server_ip", newIP);
    prefs.end();
    server.send(200, "text/plain", "IP Updated to " + newIP + ". Restarting...");
    delay(1000);
    ESP.restart(); 
  } else {
    server.send(400, "text/plain", "Please provide ?ip=192.168.x.x");
  }
});
  
  server.begin();
}

void loop() {
  handleTouch();
  server.handleClient();

  // 1. PROACTIVE WIFI MONITORING & AUTO-RECONNECT
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi connection lost. Reconnecting...");
    WiFi.disconnect();
    WiFi.begin(); 
    delay(2000); 
  }

  // 2. AUTOPILOT CHECK (Only if connected)
  if (WiFi.status() == WL_CONNECTED) {
    // 💡 只有在既不需要吃药，又不在响缺药警报时，才去问服务器
    if (!isDoseWaiting && !isOutOfStockBeeping && (millis() - lastDoseCheckTime > doseCheckInterval)) {
      checkForPendingDose();
      lastDoseCheckTime = millis();
    }
  }

  // 🚨 3A. 缺药时的断断续续警报 (30 秒)
  if (isOutOfStockBeeping) {
    if (millis() - outOfStockStartTime > outOfStockTimeout) {
      // 30秒到了，停止警报
      isOutOfStockBeeping = false;
      triggerBuzzerHardware(false); // 强制关掉 Buzzer

      Serial.println("🛑 Out of stock warning timeout. Marking as missed.");
      if (WiFi.status() == WL_CONNECTED) {
        markDoseAsMissed(pendingAdlogId); 
      }
      updateDisplayState("MedSmart System", "Ready!");
    } else {
      // 每 500ms 切换一次声音（实现断断续续响铃）
      if (millis() - lastBuzzerToggleTime > 500) {
        outOfStockBuzzerState = !outOfStockBuzzerState;
        triggerBuzzerHardware(outOfStockBuzzerState);
        lastBuzzerToggleTime = millis();
      }
    }
  }

  // 💊 3B. 正常吃药的超时检测逻辑
  if (isDoseWaiting) {
    if (millis() - doseStartTime > doseTimeout) {
      Serial.println("⏰ Time Passed! Patient missed the medicine.");
      
      isDoseWaiting = false; 
      triggerBuzzerHardware(false); 
      
      updateDisplayState("Missed Dose", pendingMedName);
      
      if (WiFi.status() == WL_CONNECTED) {
        markDoseAsMissed(pendingAdlogId); 
      }
      
      delay(4000);
      updateDisplayState("MedSmart System", "Ready!"); 
    }
  }

  // 4. HEARTBEAT TO BACKEND
  if ((millis() - lastHeartbeatTime) > heartbeatInterval) {
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = "http://" + serverIP + ":5000/device/heartbeat";
      http.begin(url);
      http.addHeader("Content-Type", "application/json");
      http.addHeader("ngrok-skip-browser-warning", "true"); 
      http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

      int batteryLevel = 100; 
      long rssi = WiFi.RSSI(); 

      String jsonPayload = "{\"device_serial\":\"" + deviceSerial + "\",\"battery\":" + String(batteryLevel) + ",\"rssi\":" + String(rssi) + "}";
      
      int httpResponseCode = http.POST(jsonPayload);
      if (httpResponseCode > 0) {
        // Serial.println("Heartbeat Sent Successfully.");
      } else {
        Serial.print("Error sending heartbeat. Code: ");
        Serial.println(httpResponseCode);
      }
      http.end(); 
    } else {
      Serial.println("Skipping heartbeat: WiFi not connected.");
    }
    lastHeartbeatTime = millis();
  }
}