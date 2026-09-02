-- 1. Add current_token column to the floors table
ALTER TABLE floors ADD COLUMN current_token VARCHAR(20) DEFAULT NULL;
