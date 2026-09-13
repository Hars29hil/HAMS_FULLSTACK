#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLEAdvertising.h>

const char* DEVICE_NAME = "Hostel_Floor_Beacon";

// Match the exact UUIDs from your Flutter App!
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

// Hardware Pins for Onboard LEDs
const int BLUE_LED_PIN = 2; 
const int RED_LED_PIN = 33;  

void setup() {
  Serial.begin(115200);
  pinMode(BLUE_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  
  // Turn Blue LED on to indicate Beacon is active
  digitalWrite(BLUE_LED_PIN, HIGH); 
  digitalWrite(RED_LED_PIN, LOW);

  // Setup BLE Device
  BLEDevice::init(DEVICE_NAME);
  
  // Setup Advertising (No Server, No Connections!)
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  
  BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
  oAdvertisementData.setFlags(0x04); // BR_EDR_NOT_SUPPORTED
  oAdvertisementData.setName("ESP32");
  oAdvertisementData.setCompleteServices(BLEUUID(SERVICE_UUID)); 
  pAdvertising->setAdvertisementData(oAdvertisementData);
  
  pAdvertising->start();
  
  Serial.println("BLE Dumb Beacon Started (Advertiser Only).");
}

void loop() {
  // Doing nothing! Just chilling and broadcasting Bluetooth signals.
  delay(1000); 
}
