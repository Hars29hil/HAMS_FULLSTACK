-- =========================================================================
-- WARNING: BEFORE RUNNING THIS, MAKE A BACKUP OF YOUR TABLE IF POSSIBLE
-- =========================================================================

-- (Steps 1 and 2 have already been successfully executed, so they are removed)

-- (Steps 1, 2, and the Foreign Key Drops have already succeeded!)

-- 3b. Now safely drop the index
ALTER TABLE attendance_records DROP INDEX unique_session_student;

-- 4. Strip the old primary key (id) and remove the old columns
ALTER TABLE attendance_records MODIFY id INT NOT NULL;
ALTER TABLE attendance_records DROP PRIMARY KEY;
ALTER TABLE attendance_records DROP COLUMN id;
ALTER TABLE attendance_records DROP COLUMN student_id;

-- 5. Create the new Primary Key so you don't get duplicates
ALTER TABLE attendance_records ADD PRIMARY KEY (session_id, bank_code);

-- 6. Add back the foreign key for session_id
ALTER TABLE attendance_records ADD CONSTRAINT fk_session 
FOREIGN KEY (session_id) REFERENCES attendance_sessions(id);
