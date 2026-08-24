# HAMS ESP32 Firmware Guide

## Architecture
Each floor contains an ESP32 board paired with an RFID reader (MFRC522) and a buzzer/LED for feedback.
The device connects directly to the local WiFi and hits the `http://<SERVER_IP>:3000/api/esp32/attendance/event` endpoint.

## Configuration
Before flashing `esp32-services/firmware/common/main.cpp`, you must change:
1. `WIFI_SSID` and `WIFI_PASS`
2. `SERVER_URL` to point to the active backend instance.
3. `DEVICE_ID` and `DEVICE_SECRET`. These must match the values securely stored in the MySQL `floor_devices` table.

## Feedback Mechanism
- **Success (`PRESENT`, `LATE`)**: Emit a short beep and turn the LED Green.
- **Rejected (`REJECTED`)**: Emit three short beeps and turn the LED Red. Typical rejection reasons:
  - Wrong floor.
  - No active session.
  - Already marked.
