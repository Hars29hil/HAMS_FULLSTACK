#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLEAdvertising.h>

const char* DEVICE_NAME = "Hostel_Floor_Beacon";

// Match the exact UUIDs from your Flutter App!
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEUUID targetServiceUUID(SERVICE_UUID);

// Hardware Pins for Onboard LEDs
const int BLUE_LED_PIN = 2; 
const int RED_LED_PIN = 33;  

// Auto-Reset Timer (Dynamic)
unsigned long ACTIVE_DURATION_MS = 2 * 60 * 60 * 1000UL; 
unsigned long tokenReceivedTime = 0;

char currentToken[20] = "NONE";
BLEAdvertising *pAdvertising;
BLEServer *pServer;
BLECharacteristic *pCharacteristic;

void updateBLEAdvertisement(const char* token) {
    // The Flutter App reads the token via a direct GATT connection (characteristic read).
    // Therefore, we don't need to bloat the BLE advertisement packet with the token!
    // This fixes the 31-byte Android BLE limit crash permanently.
    Serial.print("Token is now set to: ");
    Serial.println(token);
}

// Callback for when the Flutter App connects and writes to the ESP-32
class MyCharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue();
        if (value.length() > 0) {
            String payload = String(value.c_str());
            
            // Format can be "SET:<token>" OR "SET:<token>:<duration_minutes>"
            if (payload.startsWith("SET:")) {
                String remainder = payload.substring(4);
                String newToken = remainder;
                unsigned long newDurationMs = 2 * 60 * 60 * 1000UL; // Default 2 hours
                
                int colonIndex = remainder.indexOf(':');
                if (colonIndex > 0) {
                    newToken = remainder.substring(0, colonIndex);
                    String durationStr = remainder.substring(colonIndex + 1);
                    if (durationStr.length() > 0) {
                        newDurationMs = (unsigned long)durationStr.toInt() * 60 * 1000UL;
                    }
                }

                if (newToken != String(currentToken)) {
                    Serial.print("Received SET command via GATT. New token: ");
                    Serial.print(newToken);
                    Serial.print(" for duration(ms): ");
                    Serial.println(newDurationMs);
                    
                    // Update our own token and duration
                    newToken.toCharArray(currentToken, 20);
                    ACTIVE_DURATION_MS = newDurationMs;
                    tokenReceivedTime = millis(); // Start the timer
                    updateBLEAdvertisement(currentToken);
                    
                    // !!! THE CRITICAL FIX FOR THE WEB APP !!!
                    pCharacteristic->setValue(currentToken);
                    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    
                    // Switch to Blue LED
                    digitalWrite(RED_LED_PIN, LOW);
                    digitalWrite(BLUE_LED_PIN, HIGH);
                }
            }
        }
    }
};

void setup() {
  Serial.begin(115200);
  pinMode(BLUE_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  
  // Start in "NONE" state (Red LED on)
  digitalWrite(BLUE_LED_PIN, LOW); 
  digitalWrite(RED_LED_PIN, HIGH);

  // Setup BLE Device
  BLEDevice::init(DEVICE_NAME);
  
  // Create BLE Server (GATT)
  pServer = BLEDevice::createServer();
  
  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create Writable Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE
                    );
                    
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pCharacteristic->setValue("NONE");
  pService->start();
  
  // Setup Advertising
  pAdvertising = BLEDevice::getAdvertising();
  
  BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
  oAdvertisementData.setFlags(0x04); // BR_EDR_NOT_SUPPORTED
  oAdvertisementData.setName(DEVICE_NAME);
  pAdvertising->setAdvertisementData(oAdvertisementData);
  
  pAdvertising->start();
  
  updateBLEAdvertisement(currentToken);
  
  Serial.println("BLE Bridged Anchor Started (GATT Server + Advertiser).");
}

void loop() {
  // Check if the attendance time is over (Auto-Reset)
  if (strcmp(currentToken, "NONE") != 0) {
      if (millis() - tokenReceivedTime >= ACTIVE_DURATION_MS) {
          Serial.println("Attendance time over. Resetting to NONE.");
          strcpy(currentToken, "NONE");
          
          // !!! CRITICAL FIX !!! Reset the characteristic value to NONE as well
          pCharacteristic->setValue("NONE");
          
          updateBLEAdvertisement(currentToken);
          
          // Switch back to Red LED
          digitalWrite(BLUE_LED_PIN, LOW);
          digitalWrite(RED_LED_PIN, HIGH);
      }
  }

  delay(1000); 
}

