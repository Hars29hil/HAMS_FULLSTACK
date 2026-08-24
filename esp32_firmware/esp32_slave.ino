#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <WiFi.h>
#include <esp_now.h>

// ==========================================
// 1. CONFIGURATION
// ==========================================
// Set this to your floor's ID (e.g., 1 for Floor 1, 2 for Floor 2)
const int MY_FLOOR_ID = 1;
const char *DEVICE_NAME = "Hostel_A_Floor1";

// ==========================================
// 2. ESP-NOW DATA STRUCTURE
// ==========================================
typedef struct struct_message {
  int floor_id;
  char token[20];
} struct_message;

struct_message receivedMsg;

// ==========================================
// 3. BLUETOOTH (BLE) CONFIGURATION
// ==========================================
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
const int LED_PIN = 2; // Onboard Blue LED

// Callback when data is received from the Ground Floor Master
unsigned long lastRecvTime = 0;

void OnDataRecv(const esp_now_recv_info *info, const uint8_t *incomingData,
                int len) {
  memcpy(&receivedMsg, incomingData, sizeof(receivedMsg));

  // Update last receive time for connection tracking
  lastRecvTime = millis();

  if (receivedMsg.floor_id == MY_FLOOR_ID) {
    // Attendance window opened! Set new token.
    pCharacteristic->setValue(receivedMsg.token);
    Serial.print("Received active token: ");
    Serial.println(receivedMsg.token);

  } else if (receivedMsg.floor_id == -1 &&
             strcmp(receivedMsg.token, "CLEAR") == 0) {
    // Attendance window closed! Clear token.
    pCharacteristic->setValue("NOT_ACTIVE");
    Serial.println("Attendance window closed. Token cleared.");
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW); // Start disconnected

  // Set device as a Wi-Fi Station (Required for ESP-NOW)
  // We do NOT connect to any Wi-Fi router.
  WiFi.mode(WIFI_STA);

  // Give the Wi-Fi hardware half a second to initialize properly
  // to avoid getting 00:00:00:00:00:00
  delay(500);

  // Print MAC Address so user can copy it!
  Serial.println();
  Serial.print("🚨 IMPORTANT: My MAC Address is: ");
  Serial.println(WiFi.macAddress());
  Serial.println("🚨 Copy this MAC Address into esp32_master.ino !");
  Serial.println();

  // Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return;
  }

  // Register callback to receive tokens
  esp_now_register_recv_cb(OnDataRecv);

  // Setup BLE for this Upper Floor
  BLEDevice::init(DEVICE_NAME);
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ);
  pCharacteristic->setValue("NOT_ACTIVE");
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE Started. Waiting for ESP-NOW token from Ground Floor...");
}

void loop() {
  // If we received a message within the last 15 seconds, we are "Connected"
  if (lastRecvTime > 0 && millis() - lastRecvTime < 15000) {
    digitalWrite(LED_PIN, HIGH); // Blue LED ON (Connected!)
  } else {
    // Disconnected / Lost connection!
    digitalWrite(LED_PIN, LOW);              // Blue LED OFF
    pCharacteristic->setValue("NOT_ACTIVE"); // Clear token just in case
  }

  delay(100);
}
