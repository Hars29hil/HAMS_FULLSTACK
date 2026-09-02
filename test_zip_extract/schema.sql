-- ============================================
-- Hostel Attendance System - MySQL Schema
-- Import in phpMyAdmin (XAMPP) or:
-- mysql -u root -p < schema.sql
-- ============================================

-- (Database creation is handled by Hostinger Control Panel)
-- ---------------------------------------------
-- Students
-- ---------------------------------------------
CREATE TABLE students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    floor_id INT NOT NULL,
    device_uuid VARCHAR(100) DEFAULT NULL,
    assigned_mobile VARCHAR(20) DEFAULT NULL,
    rebind_count INT DEFAULT 0,
    last_rebind_at DATETIME DEFAULT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    fcm_token VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------
-- Floor Leaders
-- ---------------------------------------------
CREATE TABLE floor_leaders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    floor_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------
-- Floors / ESP32 devices (one row per floor)
-- ---------------------------------------------
CREATE TABLE floors (
    floor_id INT PRIMARY KEY,
    floor_name VARCHAR(50) NOT NULL,
    esp32_ble_service_uuid VARCHAR(100) NOT NULL,
    has_wifi BOOLEAN DEFAULT FALSE
);

-- ---------------------------------------------
-- Rebind requests (floor-leader approved flow)
-- ---------------------------------------------
CREATE TABLE rebind_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    new_device_uuid VARCHAR(100) NOT NULL,
    floor_id INT NOT NULL,
    status ENUM('pending','code_generated','completed','expired','rejected') DEFAULT 'pending',
    code_hash VARCHAR(255) DEFAULT NULL,
    code_expires_at DATETIME DEFAULT NULL,
    generated_by INT DEFAULT NULL,
    completed_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (generated_by) REFERENCES floor_leaders(id)
);

-- ---------------------------------------------
-- Attendance sessions (a roll-call window)
-- ---------------------------------------------
CREATE TABLE attendance_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    floor_id INT NOT NULL,
    session_date DATE NOT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------
-- Attendance records
-- ---------------------------------------------
CREATE TABLE attendance_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    student_id INT NOT NULL,
    floor_id INT NOT NULL,
    device_uuid VARCHAR(100) NOT NULL,
    rssi INT DEFAULT NULL,
    ble_token_used VARCHAR(100) NOT NULL,
    marked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_session_student (session_id, student_id),
    FOREIGN KEY (session_id) REFERENCES attendance_sessions(id),
    FOREIGN KEY (student_id) REFERENCES students(id)
);

-- ---------------------------------------------
-- Seed floors 0-9 (edit BLE UUIDs to match your ESP32 firmware)
-- ---------------------------------------------
INSERT INTO floors (floor_id, floor_name, esp32_ble_service_uuid, has_wifi) VALUES
(0, 'Ground Floor', '0000AA00-0000-1000-8000-00805F9B34FB', TRUE),
(1, 'Floor 1',      '0000AA01-0000-1000-8000-00805F9B34FB', FALSE),
(2, 'Floor 2',      '0000AA02-0000-1000-8000-00805F9B34FB', FALSE),
(3, 'Floor 3',      '0000AA03-0000-1000-8000-00805F9B34FB', FALSE),
(4, 'Floor 4',      '0000AA04-0000-1000-8000-00805F9B34FB', FALSE),
(5, 'Floor 5',      '0000AA05-0000-1000-8000-00805F9B34FB', FALSE),
(6, 'Floor 6',      '0000AA06-0000-1000-8000-00805F9B34FB', FALSE),
(7, 'Floor 7',      '0000AA07-0000-1000-8000-00805F9B34FB', FALSE),
(8, 'Floor 8',      '0000AA08-0000-1000-8000-00805F9B34FB', FALSE),
(9, 'Floor 9',      '0000AA09-0000-1000-8000-00805F9B34FB', FALSE);

-- ---------------------------------------------
-- System Settings (Global configurations)
-- ---------------------------------------------
CREATE TABLE system_settings (
    setting_key VARCHAR(50) PRIMARY KEY,
    setting_value VARCHAR(255) NOT NULL,
    description TEXT NULL
);

-- Seed default daily schedule (9:00 PM to 9:30 PM)
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
('DAILY_START_TIME', '21:00', 'Daily time when attendance automatically opens (HH:MM)'),
('DAILY_END_TIME', '21:30', 'Daily time when attendance automatically closes (HH:MM)');
