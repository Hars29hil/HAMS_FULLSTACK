-- Hostel Attendance Management System (HAMS)
-- MySQL Database Schema for XAMPP

CREATE DATABASE IF NOT EXISTS `hams`;
USE `hams`;

-- 1. System Settings
CREATE TABLE `system_settings` (
  `setting_key` VARCHAR(50) PRIMARY KEY,
  `setting_value` VARCHAR(255) NOT NULL,
  `description` TEXT,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Default settings
INSERT INTO `system_settings` (`setting_key`, `setting_value`, `description`) VALUES
('ATTENDANCE_DURATION_MINUTES', '10', 'Duration for which attendance session remains active'),
('REMINDER_TIME_MINUTES', '5', 'Time after start to send reminder notification'),
('ALLOW_LATE_ATTENDANCE', 'true', 'Allow students to mark attendance after session is closed');

-- 2. Users (Authentication base)
CREATE TABLE `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `username` VARCHAR(100) UNIQUE NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` ENUM('ADMIN', 'STUDENT', 'WARDEN', 'LEADER') NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 3. Admins
CREATE TABLE `admins` (
  `admin_id` INT PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(100) UNIQUE NOT NULL,
  FOREIGN KEY (`admin_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 4. Floors
CREATE TABLE `floors` (
  `floor_id` VARCHAR(50) PRIMARY KEY, -- e.g., FLOOR-01
  `name` VARCHAR(100) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Rooms
CREATE TABLE `rooms` (
  `room_id` VARCHAR(50) PRIMARY KEY, -- e.g., ROOM-101
  `floor_id` VARCHAR(50) NOT NULL,
  `room_number` VARCHAR(20) NOT NULL,
  FOREIGN KEY (`floor_id`) REFERENCES `floors`(`floor_id`) ON DELETE CASCADE
);

-- 6. Students
CREATE TABLE `students` (
  `student_id` VARCHAR(50) PRIMARY KEY, -- Using custom ID for external API compatibility
  `user_id` INT UNIQUE, -- Nullable if they don't have login access initially
  `name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(100) UNIQUE,
  `room_id` VARCHAR(50),
  `floor_id` VARCHAR(50),
  `status` VARCHAR(20) DEFAULT 'ACTIVE',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`room_id`) REFERENCES `rooms`(`room_id`) ON DELETE SET NULL,
  FOREIGN KEY (`floor_id`) REFERENCES `floors`(`floor_id`) ON DELETE SET NULL
);

-- 7. ESP32 Floor Devices
CREATE TABLE `floor_devices` (
  `device_id` VARCHAR(50) PRIMARY KEY, -- e.g., ESP32-F01
  `floor_id` VARCHAR(50) NOT NULL,
  `device_secret` VARCHAR(255) NOT NULL,
  `device_name` VARCHAR(100) NOT NULL,
  `firmware_version` VARCHAR(20),
  `ip_address` VARCHAR(45),
  `last_seen` TIMESTAMP,
  `status` ENUM('ONLINE', 'OFFLINE') DEFAULT 'OFFLINE',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`floor_id`) REFERENCES `floors`(`floor_id`) ON DELETE CASCADE
);

-- 8. Device Logs
CREATE TABLE `device_logs` (
  `log_id` INT AUTO_INCREMENT PRIMARY KEY,
  `device_id` VARCHAR(50) NOT NULL,
  `event_type` VARCHAR(50) NOT NULL,
  `message` TEXT,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`device_id`) REFERENCES `floor_devices`(`device_id`) ON DELETE CASCADE
);

-- 9. Attendance Sessions
CREATE TABLE `attendance_sessions` (
  `session_id` INT AUTO_INCREMENT PRIMARY KEY,
  `floor_id` VARCHAR(50) NOT NULL,
  `start_time` TIMESTAMP NULL,
  `close_time` TIMESTAMP NULL,
  `status` ENUM('SCHEDULED', 'ACTIVE', 'CLOSED', 'CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
  `created_by` INT,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`floor_id`) REFERENCES `floors`(`floor_id`) ON DELETE CASCADE,
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`) ON DELETE SET NULL
);

-- 10. Attendance Records
CREATE TABLE `attendance_records` (
  `record_id` INT AUTO_INCREMENT PRIMARY KEY,
  `session_id` INT NOT NULL,
  `student_id` VARCHAR(50) NOT NULL,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `status` ENUM('PRESENT', 'LATE', 'ABSENT', 'REJECTED') NOT NULL,
  `remarks` TEXT,
  FOREIGN KEY (`session_id`) REFERENCES `attendance_sessions`(`session_id`) ON DELETE CASCADE,
  FOREIGN KEY (`student_id`) REFERENCES `students`(`student_id`) ON DELETE CASCADE,
  UNIQUE KEY `unique_student_session` (`session_id`, `student_id`)
);

-- 11. Notifications
CREATE TABLE `notifications` (
  `notification_id` INT AUTO_INCREMENT PRIMARY KEY,
  `type` VARCHAR(50) NOT NULL,
  `message` TEXT NOT NULL,
  `target_role` ENUM('ADMIN', 'STUDENT', 'WARDEN', 'LEADER', 'ALL') NOT NULL,
  `target_user_id` INT, -- Nullable for broadcast
  `is_read` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`target_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);
