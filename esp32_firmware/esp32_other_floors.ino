#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// ==========================================
// 1. CONFIGURATION (CHANGE FOR EACH ESP-32)
// ==========================================
const char* DEVICE_NAME = "Hostel_A_Floor1"; // E.g., "Hostel_A_Floor1" or "Hostel_A_Floor2"

// ==========================================
// 2. BLUETOOTH CONFIGURATION (DO NOT CHANGE)
// ==========================================
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// This is the static token that the non-WiFi floors will broadcast.
// The backend recognizes this and bypasses the crypto check for non-Ground floors.
const char* STATIC_TOKEN = "verified_by_esp32";

void setup() {
  Serial.begin(115200);

  // Initialize BLE
  BLEDevice::init(DEVICE_NAME);
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create the characteristic and make it READABLE
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ
                                       );

  // Set the static token value
  pCharacteristic->setValue(STATIC_TOKEN);

  pService->start();
  
  // Start Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE Server is running and advertising.");
  Serial.println("This ESP-32 does NOT need Wi-Fi. It is using the static proximity token.");
}

void loop() {
  // We do not need to do anything in the loop! 
  // The token never changes, so we just let the ESP-32 sit there and broadcast BLE.
  delay(1000);
}
