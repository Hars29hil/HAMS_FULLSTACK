# Hostel Attendance Management System (HAMS) — Technical Documentation

## 1. System Overview
HAMS is a secure, proximity-based attendance system designed for multi-floor hostels. It ensures students are physically present on their assigned floors using Bluetooth Low Energy (BLE) beacons (ESP32) and rotating cryptographic tokens.

### Architecture
- **Frontend App**: Flutter (Android/iOS)
- **Backend API**: Node.js (Express.js) hosted on Hostinger
- **Database**: MySQL (Hostinger)
- **Hardware Beacons**: ESP32 Microcontrollers (Master & Slave configuration via ESP-NOW)

---

## 2. Hardware Architecture (ESP32)

Because not all floors have Wi-Fi access, the hardware uses a **Master-Slave** topology.

### The Master Node (e.g., 8th Floor)
- **Connectivity**: Connects to the local Wi-Fi router.
- **Role**: 
  1. Fetches the active rotating tokens for *all* floors from the Backend API every 30 seconds.
  2. Updates its own BLE beacon with its floor's token.
  3. Broadcasts the other floors' tokens over the air using **ESP-NOW** (a direct radio protocol).
- **BLE Beacon**: Advertises as `ESP32-Floor8`.

### The Slave Node (e.g., 9th Floor)
- **Connectivity**: No Wi-Fi required.
- **Role**: 
  1. Actively scans Wi-Fi radio channels (Channel Hopping) until it finds the Master's ESP-NOW signal.
  2. Receives its specific token from the Master.
  3. Updates its own BLE beacon with the token.
- **BLE Beacon**: Advertises as `ESP32-Floor9`.

---

## 3. Database Schema (MySQL)

The database consists of several core tables to manage users, floors, and attendance records.

| Table Name | Purpose | Key Columns |
|---|---|---|
| `floors` | Defines hostel floors and their active BLE tokens | `floor_id`, `floor_name`, `current_token`, `last_token_update` |
| `users` | Handles login credentials and roles | `id`, `username`, `password_hash`, `role` (student, floor_leader, admin) |
| `students` | Student profiles linked to a user account | `id`, `user_id`, `student_code`, `name`, `floor_id`, `device_uuid` |
| `floor_leaders` | Floor leader profiles | `id`, `user_id`, `floor_id`, `name` |
| `attendance_sessions` | A daily time window when attendance is active | `id`, `floor_id`, `session_date`, `starts_at`, `ends_at` |
| `attendance_records` | The actual log of a student's attendance | `session_id`, `bank_code`, `student_name`, `floor_id`, `rssi`, `ble_token_used` |
| `system_settings` | Global configurations | `setting_key`, `setting_value` (e.g., DAILY_START_TIME, DAILY_END_TIME) |

> [!NOTE]
> The `attendance_records` table uses a composite Primary Key (`session_id`, `bank_code`) to prevent a student from marking attendance multiple times in the same session.

---

## 4. Backend API Endpoints

The Node.js backend uses JWT (JSON Web Tokens) for authentication. All endpoints (except Auth/ESP32) require a `Bearer <token>` in the Authorization header.

### 🔐 Authentication
- **`POST /api/auth/login`**
  - **Body**: `{ "username": "...", "password": "...", "device_uuid": "..." }`
  - **Response**: JWT Token, User Role, and Profile Data.
  - **Logic**: Verifies credentials and ensures the student is logging in from their registered `device_uuid` (prevents device sharing).

### 📡 ESP32 Hardware
- **`GET /api/esp32/active-tokens`**
  - **Headers**: `x-api-key: <GATEWAY_API_KEY>`
  - **Response**: JSON array of floors and their currently active tokens.
  - **Logic**: Used exclusively by the Master ESP32 to fetch tokens.

### 🙋‍♂️ Student Attendance
- **`GET /api/attendance/my-status`**
  - **Response**: Boolean indicating if the student has already marked attendance today, and whether the attendance window is currently open.
- **`POST /api/attendance/mark`**
  - **Body**: `{ "ble_token": "69574D", "rssi": -65 }`
  - **Response**: Success (201) or Error (403 Invalid Token / 400 Window Closed).
  - **Logic**: 
    1. Verifies the attendance time window is open.
    2. Checks that the provided `ble_token` matches the `current_token` stored in the DB for the student's assigned floor.
    3. Inserts a record into `attendance_records`.

### 👑 Floor Leader / Admin
- **`GET /api/attendance/session/:id/records`**
  - **Response**: List of all students who marked attendance for a specific session on the leader's floor.
- **`GET /api/students/floor/:floor_id`**
  - **Response**: List of all students assigned to that floor.

---

## 5. Frontend App (Flutter)

The Flutter application handles the user interface and the complex Bluetooth scanning logic.

### Core Dependencies
- `flutter_blue_plus`: For scanning and interacting with BLE devices.
- `dio`: For making HTTP requests to the backend API.
- `shared_preferences`: For local storage of the JWT and user session.

### The Attendance Marking Flow (Security)
To mark attendance, the Flutter app performs the following secure handshake:
1. **Verification**: Checks if the backend says the attendance window is open.
2. **Scan**: Turns on BLE and scans the area for a device broadcasting the unique HAMS Service UUID (`4fafc201...`).
3. **Connect**: Connects to the ESP32.
4. **Read**: Reads the dynamic token generated by the ESP32 (e.g., `69574D`).
5. **Disconnect**: Instantly disconnects so the ESP32 can serve the next student.
6. **Submit**: Sends the read token to the backend. The backend validates it, proving the student is physically standing next to the ESP32 on their assigned floor.

> [!IMPORTANT]
> The Flutter app relies on the ESP32's **Service UUID** rather than its device name to identify it, as Android OS frequently caches device names as `N/A`, which would otherwise break the scanning process.
