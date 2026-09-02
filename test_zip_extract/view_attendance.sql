CREATE OR REPLACE VIEW view_attendance_records AS
SELECT 
    ar.id AS attendance_record_id,
    s.student_code AS bank_code,
    s.name AS student_name,
    f.floor_name,
    ar.rssi AS signal_strength,
    ar.marked_at
FROM 
    attendance_records ar
JOIN 
    students s ON s.id = ar.student_id
JOIN 
    floors f ON f.floor_id = ar.floor_id
ORDER BY 
    ar.marked_at DESC;
