#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// Environment Variables
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASS";

const char* SERVER_URL = "http://YOUR_SERVER_IP:3000/api/esp32";
const char* DEVICE_ID = "DEV_F1_01";
const char* DEVICE_SECRET = "super_secret_key_123";
const char* FIRMWARE_VERSION = "1.0.0";

// Mock RFID scan function
String scanRFID() {
  // In reality, read from MFRC522 or similar here
  // Return student_id string, e.g. "STU001"
  return "STU001"; 
}

void sendHeartbeat() {
  if(WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = String(SERVER_URL) + "/heartbeat";
    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<200> doc;
    doc["device_id"] = DEVICE_ID;
    doc["device_secret"] = DEVICE_SECRET;
    doc["firmware_version"] = FIRMWARE_VERSION;

    String requestBody;
    serializeJson(doc, requestBody);

    int httpResponseCode = http.POST(requestBody);
    Serial.print("Heartbeat HTTP Response code: ");
    Serial.println(httpResponseCode);
    
    http.end();
  }
}

void sendAttendanceEvent(String studentId) {
  if(WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = String(SERVER_URL) + "/attendance/event";
    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<200> doc;
    doc["device_id"] = DEVICE_ID;
    doc["device_secret"] = DEVICE_SECRET;
    doc["student_id"] = studentId;

    String requestBody;
    serializeJson(doc, requestBody);

    int httpResponseCode = http.POST(requestBody);
    String responseBody = http.getString();
    
    Serial.print("Attendance HTTP Response code: ");
    Serial.println(httpResponseCode);
    Serial.println(responseBody);
    
    // Parse response
    // If success = true and attendance.status = "PRESENT", beep success
    // If success = false, beep error (Wrong floor / Session closed)
    http.end();
  }
}

void setup() {
  Serial.begin(115200);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected to WiFi");
}

void loop() {
  // 1. Send heartbeat every 60 seconds
  static unsigned long lastHeartbeat = 0;
  if (millis() - lastHeartbeat > 60000) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }

  // 2. Poll for RFID card
  String scannedStudentId = scanRFID();
  if (scannedStudentId.length() > 0) {
    sendAttendanceEvent(scannedStudentId);
    delay(2000); // debounce delay
  }
}
