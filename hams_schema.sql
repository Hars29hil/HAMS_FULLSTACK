CREATE DATABASE IF NOT EXISTS hams;
USE hams;

-- Users table (Admins, Wardens, Leaders)
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('ADMIN', 'WARDEN', 'LEADER', 'STUDENT') NOT NULL DEFAULT 'STUDENT',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Default Admin User (Password: password123)
-- Hash generated using bcrypt for 'password123'
INSERT INTO users (username, password_hash, role) VALUES 
('admin', '$2a$10$X8w.m3eYd.Yx9G01j3vD0O1E2s7aZ.Z49d95z8v2JkOq1V71p3iG', 'ADMIN') 
ON DUPLICATE KEY UPDATE username=username;

-- Floors table
CREATE TABLE IF NOT EXISTS floors (
  floor_id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Rooms table
CREATE TABLE IF NOT EXISTS rooms (
  room_id VARCHAR(50) PRIMARY KEY,
  floor_id VARCHAR(50) NOT NULL,
  room_number VARCHAR(50) NOT NULL,
  FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE
);

-- Students table (Cached from external API)
CREATE TABLE IF NOT EXISTS students (
  student_id VARCHAR(100) PRIMARY KEY,
  user_id INT NULL,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NULL,
  room_id VARCHAR(50) NULL,
  floor_id VARCHAR(50) NULL,
  assigned_mobile VARCHAR(20) NULL,
  status VARCHAR(20) DEFAULT 'ACTIVE',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE SET NULL,
  FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL
);

-- Student Devices table
CREATE TABLE IF NOT EXISTS student_devices (
  id INT AUTO_INCREMENT PRIMARY KEY,
  device_uuid VARCHAR(255) UNIQUE NOT NULL,
  student_id VARCHAR(100) NOT NULL,
  platform VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_seen TIMESTAMP NULL,
  status VARCHAR(20) DEFAULT 'ACTIVE',
  FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

-- Floor Leaders table
CREATE TABLE IF NOT EXISTS floor_leaders (
  user_id INT PRIMARY KEY,
  floor_id VARCHAR(50) NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE
);

-- Device Rebind Requests
CREATE TABLE IF NOT EXISTS rebind_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  student_id VARCHAR(100) NOT NULL,
  new_device_uuid VARCHAR(255) NOT NULL,
  floor_id VARCHAR(50) NOT NULL,
  status ENUM('PENDING', 'CODE_GENERATED', 'COMPLETED', 'REJECTED', 'EXPIRED') DEFAULT 'PENDING',
  code_hash VARCHAR(255) NULL,
  code_expires_at DATETIME NULL,
  generated_by INT NULL,
  failed_attempts INT DEFAULT 0,
  completed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
  FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE,
  FOREIGN KEY (generated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Device Unbind/Logout Requests (Legacy)
CREATE TABLE IF NOT EXISTS device_unbind_requests (
  request_id INT AUTO_INCREMENT PRIMARY KEY,
  student_id VARCHAR(100) NOT NULL,
  device_id VARCHAR(255) NOT NULL,
  status ENUM('PENDING', 'APPROVED', 'REJECTED') DEFAULT 'PENDING',
  pin_code VARCHAR(6) NULL,
  pin_expires_at DATETIME NULL,
  failed_attempts INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

-- Devices table
CREATE TABLE IF NOT EXISTS floor_devices (
  device_id VARCHAR(50) PRIMARY KEY,
  floor_id VARCHAR(50) NOT NULL,
  device_secret VARCHAR(255) NOT NULL,
  device_name VARCHAR(100) NOT NULL,
  firmware_version VARCHAR(20) NULL,
  ip_address VARCHAR(50) NULL,
  status ENUM('ONLINE', 'OFFLINE') DEFAULT 'OFFLINE',
  last_seen TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE
);

-- Attendance Sessions
CREATE TABLE IF NOT EXISTS attendance_sessions (
  session_id INT AUTO_INCREMENT PRIMARY KEY,
  floor_id VARCHAR(50) NOT NULL,
  start_time DATETIME NOT NULL,
  close_time DATETIME NULL,
  status ENUM('SCHEDULED', 'ACTIVE', 'CLOSED', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
  created_by INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE
);

-- Attendance Records
CREATE TABLE IF NOT EXISTS attendance_records (
  record_id INT AUTO_INCREMENT PRIMARY KEY,
  session_id INT NOT NULL,
  student_id VARCHAR(100) NOT NULL,
  device_id VARCHAR(255) NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  status ENUM('PRESENT', 'LATE', 'ABSENT', 'REJECTED') NOT NULL,
  remarks VARCHAR(255) NULL,
  FOREIGN KEY (session_id) REFERENCES attendance_sessions(session_id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
  UNIQUE KEY unique_session_student (session_id, student_id),
  UNIQUE KEY unique_session_device (session_id, device_id)
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
  notification_id INT AUTO_INCREMENT PRIMARY KEY,
  type VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  target_role VARCHAR(20) NOT NULL,
  target_user_id INT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System Settings
CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(50) PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  description TEXT NULL
);

-- Allow late attendance configuration
INSERT INTO system_settings (setting_key, setting_value, description) 
VALUES ('ALLOW_LATE_ATTENDANCE', 'true', 'Allows students to scan even after session is closed, marking them as LATE') 
ON DUPLICATE KEY UPDATE setting_value=setting_value;
