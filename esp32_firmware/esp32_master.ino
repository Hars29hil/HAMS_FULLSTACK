#include <WiFi.h>
#include <HTTPClient.h>
#include <esp_now.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// ==========================================
// 1. CONFIGURATION
// ==========================================
const char* WIFI_SSID = "Harshil";
const char* WIFI_PASS = "12345678";
const char* API_URL   = "https://darkgrey-cattle-615652.hostingersite.com/api/esp32/active-tokens";

// Define the Master's Floor ID (usually 0 for Ground)
const int MY_FLOOR_ID = 0;

// ==========================================
// 2. ESP-NOW SLAVE MAC ADDRESSES
// ==========================================
// Add the MAC addresses of your Upper Floor ESP-32s here.
// You can find the MAC address of an ESP32 by uploading a blank sketch and reading Serial output,
// or using a WiFi scanner app.
uint8_t floor1_mac[] = {0xB0, 0xB2, 0x1C, 0xA9, 0x13, 0x94}; // Real MAC of Floor 1 Slave
uint8_t floor2_mac[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}; // REPLACE THIS WITH REAL MAC

// Define the data structure to send over ESP-NOW
typedef struct struct_message {
    int floor_id;
    char token[20]; 
} struct_message;

struct_message tokenMsg;

// ==========================================
// 3. BLUETOOTH (BLE) CONFIGURATION
// ==========================================
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
const int LED_PIN = 2; // Onboard Blue LED

unsigned long lastSyncTime = 0;
const unsigned long SYNC_INTERVAL = 30000; // 30 seconds

// Callback when data is sent via ESP-NOW
void OnDataSent(const esp_now_send_info_t *tx_info, esp_now_send_status_t status) {
  Serial.print("\r\nLast Packet Send Status:\t");
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "Delivery Success" : "Delivery Fail");
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Connect to Wi-Fi
  WiFi.mode(WIFI_STA);
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nWiFi Connected!");

  // Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return;
  }
  
  esp_now_register_send_cb(OnDataSent);

  // Register peers (Slaves)
  esp_now_peer_info_t peerInfo = {};
  peerInfo.channel = 0;  
  peerInfo.encrypt = false;
  
  // Register Floor 1
  memcpy(peerInfo.peer_addr, floor1_mac, 6);
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add Floor 1 peer");
  }
  // Register Floor 2
  memcpy(peerInfo.peer_addr, floor2_mac, 6);
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("Failed to add Floor 2 peer");
  }

  // Setup BLE for Ground Floor
  BLEDevice::init("ESP32-GROUND");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ
                    );
  pCharacteristic->setValue("NOT_ACTIVE");
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("BLE Started for Ground Floor.");

  // Force an immediate sync on the first loop instead of waiting 30 seconds
  lastSyncTime = millis() - SYNC_INTERVAL;
}

unsigned long lastHeartbeatTime = 0;
const unsigned long HEARTBEAT_INTERVAL = 5000; // 5 seconds

void loop() {
  // 1. Connection Indicator: Blue LED ON if connected to Wi-Fi
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(LED_PIN, HIGH);
  } else {
    digitalWrite(LED_PIN, LOW);
  }

  // 2. Fetch tokens from API every 30 seconds
  if (millis() - lastSyncTime >= SYNC_INTERVAL) {
    lastSyncTime = millis();

    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      http.begin(API_URL);
      int httpCode = http.GET();

      if (httpCode == 200) {
        String payload = http.getString();
        
        // Parse JSON response
        DynamicJsonDocument doc(1024);
        DeserializationError error = deserializeJson(doc, payload);
        
        if (!error) {
          bool isActive = doc["active"];
          JsonArray tokens = doc["tokens"];
          
          bool hasFloor1 = false;
          bool hasFloor2 = false;

          if (isActive) {
            for (JsonObject floor : tokens) {
              int floorId = floor["floor_id"];
              const char* currentToken = floor["current_token"];
              
              // If token is an empty string in DB, treat it as inactive
              if (currentToken == nullptr || strlen(currentToken) == 0) {
                 continue;
              }
              
              if (floorId == MY_FLOOR_ID) {
                // Update my own BLE
                pCharacteristic->setValue(currentToken);
              } 
              else if (floorId == 1) {
                hasFloor1 = true;
                tokenMsg.floor_id = floorId;
                strcpy(tokenMsg.token, currentToken);
                // We don't send here, we send in the heartbeat!
              }
              else if (floorId == 2) {
                hasFloor2 = true;
                // We'll handle this in heartbeat logic if needed
              }
            }
          } 

          // If no token, set them to CLEAR
          if (!hasFloor1) {
             tokenMsg.floor_id = -1;
             strcpy(tokenMsg.token, "CLEAR");
          }
          if (!isActive && !hasFloor1) {
            pCharacteristic->setValue("NOT_ACTIVE");
          }

        } else {
          Serial.println("JSON Parse Error");
        }
      } else {
        Serial.printf("HTTP GET Failed, code: %d\n", httpCode);
      }
      http.end();
    }
  }

  // 3. Send Heartbeat to Slaves every 5 seconds
  if (millis() - lastHeartbeatTime >= HEARTBEAT_INTERVAL) {
    lastHeartbeatTime = millis();
    esp_now_send(floor1_mac, (uint8_t *) &tokenMsg, sizeof(tokenMsg));
    esp_now_send(floor2_mac, (uint8_t *) &tokenMsg, sizeof(tokenMsg));
  }
}
