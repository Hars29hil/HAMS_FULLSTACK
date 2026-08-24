#include <WiFi.h>
#include <time.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include "mbedtls/md.h"

// ==========================================
// 1. CONFIGURATION (CHANGE FOR EACH ESP-32)
// ==========================================
const int FLOOR_ID = 1; // E.g., 1 for Floor 1, 2 for Floor 2
const char* DEVICE_NAME = "Hostel_A_Floor1"; // E.g., "Hostel_A_Floor1" or "ESP32-GROUND"

// WiFi Credentials (Only used to sync the clock)
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// ==========================================
// 2. SECURITY CONFIGURATION (DO NOT CHANGE)
// ==========================================
// Must match the exact SECRET in your backend's .env file
const char* BLE_TOKEN_SECRET = "a9f4c8b2d7e1564f8a3b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f";
const int ROTATION_SECONDS = 45;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Global Variables
BLECharacteristic *pCharacteristic;
String currentToken = "";

// NTP Servers
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 0; // Using UTC for time slot calculation
const int   daylightOffset_sec = 0;

void setup() {
  Serial.begin(115200);

  // 1. Connect to WiFi to sync time
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");

  // 2. Sync Time via NTP
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }
  Serial.println("Time synchronized successfully!");
  
  // Optional: Disconnect WiFi to save power (Not doing any backend calls!)
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  Serial.println("WiFi disconnected. ESP-32 is now running on Bluetooth only!");

  // 3. Initialize BLE
  BLEDevice::init(DEVICE_NAME);
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ
                    );

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE Server is running and advertising.");
}

String computeHMAC(int floorId, unsigned long unixSeconds) {
  // Calculate time slot
  unsigned long timeSlot = unixSeconds / ROTATION_SECONDS;
  String payload = String(floorId) + ":" + String(timeSlot);

  // Create HMAC-SHA256
  mbedtls_md_context_t ctx;
  mbedtls_md_type_t md_type = MBEDTLS_MD_SHA256;
  
  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(md_type), 1);
  mbedtls_md_hmac_starts(&ctx, (const unsigned char *)BLE_TOKEN_SECRET, strlen(BLE_TOKEN_SECRET));
  mbedtls_md_hmac_update(&ctx, (const unsigned char *)payload.c_str(), payload.length());
  
  unsigned char hmacResult[32];
  mbedtls_md_hmac_finish(&ctx, hmacResult);
  mbedtls_md_free(&ctx);

  // Convert to HEX string
  String hexStr = "";
  for (int i = 0; i < 32; i++) {
    char str[3];
    sprintf(str, "%02x", (int)hmacResult[i]);
    hexStr += str;
  }
  
  // Return the first 8 characters
  return hexStr.substring(0, 8);
}

void loop() {
  time_t now;
  time(&now);

  String newToken = computeHMAC(FLOOR_ID, now);

  // If the token rotated, update the Bluetooth Characteristic
  if (newToken != currentToken) {
    currentToken = newToken;
    pCharacteristic->setValue(currentToken.c_str());
    Serial.print("New Token Generated: ");
    Serial.println(currentToken);
  }

  // Sleep for 1 second before checking time again
  delay(1000);
}
