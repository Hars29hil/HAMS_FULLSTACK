const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { verifyStudent, verifyFloorLeader, verifyAdminOrFloorLeader } = require('../middleware/auth');
const { isTokenValid } = require('../utils/bleToken');
const admin = require('../config/firebase');

const MIN_RSSI = parseInt(process.env.MIN_RSSI || '-100', 10);

// ------------------------------------------------------------
// GET /api/attendance/my-status
// Returns the student's attendance status for today
// ------------------------------------------------------------
router.get('/my-status', verifyStudent, async (req, res) => {
  try {
    const studentId = req.student.id;
    const floorId = req.student.floor_id || 0; // Default to 0 if undefined to prevent mysql2 crash

    // Fetch global schedule
    const [settingsRows] = await pool.query(
      'SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ("DAILY_START_TIME", "DAILY_END_TIME")'
    );
    let startTimeStr = '21:00';
    let endTimeStr = '21:30';
    for (const row of settingsRows) {
      if (row.setting_key === 'DAILY_START_TIME') startTimeStr = row.setting_value;
      if (row.setting_key === 'DAILY_END_TIME') endTimeStr = row.setting_value;
    }

    const now = new Date();
    const [startH, startM] = startTimeStr.split(':').map(Number);
    const [endH, endM] = endTimeStr.split(':').map(Number);
    const startDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), startH, startM, 0);
    const endDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), endH, endM, 0);
    const attendanceActive = now >= startDt && now <= endDt;

    const sessionDate = now.toISOString().slice(0, 10);
    let alreadyMarked = false;

    const [sessions] = await pool.query(
      'SELECT id FROM attendance_sessions WHERE floor_id = ? AND session_date = ?',
      [floorId, sessionDate]
    );

    if (sessions.length > 0) {
      const sessionId = sessions[0].id;
      
      const [studentRows] = await pool.query('SELECT student_code FROM students WHERE id = ?', [studentId]);
      if (studentRows.length > 0) {
          const bankCode = studentRows[0].student_code;
          const [records] = await pool.query(
            'SELECT bank_code FROM attendance_records WHERE session_id = ? AND bank_code = ?',
            [sessionId, bankCode]
          );
          alreadyMarked = records.length > 0;
      }
    }

    return res.json({
      success: true,
      data: {
        already_marked: alreadyMarked,
        start_time: startTimeStr,
        end_time: endTimeStr,
        attendance_active: attendanceActive
      }
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Could not check attendance status. Please try again.' });
  }
});

// ------------------------------------------------------------
// GET /api/attendance/schedule
// ------------------------------------------------------------
router.get('/schedule', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ("DAILY_START_TIME", "DAILY_END_TIME")');
    const schedule = { start_time: '00:00', end_time: '23:59' };
    for (const row of rows) {
      if (row.setting_key === 'DAILY_START_TIME') schedule.start_time = row.setting_value;
      if (row.setting_key === 'DAILY_END_TIME') schedule.end_time = row.setting_value;
    }
    return res.json({ success: true, data: schedule });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// PUT /api/attendance/schedule
// ------------------------------------------------------------
router.put('/schedule', verifyAdminOrFloorLeader, async (req, res) => {
  try {
    const { startTime, endTime } = req.body;
    if (!startTime || !endTime) {
      return res.status(400).json({ success: false, message: 'Missing startTime or endTime' });
    }

    await pool.query('UPDATE system_settings SET setting_value = ? WHERE setting_key = "DAILY_START_TIME"', [startTime]);
    await pool.query('UPDATE system_settings SET setting_value = ? WHERE setting_key = "DAILY_END_TIME"', [endTime]);

    const now = new Date();
    const [startH, startM] = startTime.split(':').map(Number);
    const [endH, endM] = endTime.split(':').map(Number);
    
    if (startTime !== endTime) {
      try {
        const [students] = await pool.query('SELECT fcm_token FROM students WHERE fcm_token IS NOT NULL');
        const tokens = students.map(s => s.fcm_token).filter(t => t);
        
        if (tokens.length > 0) {
          const message = {
            notification: {
              title: 'Attendance Update ⏰',
              body: `The attendance window has been scheduled from ${startTime} to ${endTime}.`,
            },
            tokens: tokens,
          };
          
          admin.messaging().sendMulticast(message)
            .then((response) => console.log(response.successCount + ' messages sent'))
            .catch((error) => console.error('Error sending FCM:', error));
        }
      } catch (fcmErr) {
        console.error('FCM DB error:', fcmErr);
      }
    }

    return res.json({ success: true, message: 'Daily schedule updated successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/attendance/mark
// ------------------------------------------------------------
router.post('/mark', verifyStudent, async (req, res) => {
  try {
    const { ble_token, rssi } = req.body;
    if (!ble_token || rssi === undefined) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    const floorId = req.student.floor_id || 0;
    const studentId = req.student.id;

    const [settingsRows] = await pool.query('SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ("DAILY_START_TIME", "DAILY_END_TIME")');
    let startTimeStr = '21:00';
    let endTimeStr = '21:30';
    for (const row of settingsRows) {
      if (row.setting_key === 'DAILY_START_TIME') startTimeStr = row.setting_value;
      if (row.setting_key === 'DAILY_END_TIME') endTimeStr = row.setting_value;
    }

    const now = new Date();
    const [startH, startM] = startTimeStr.split(':').map(Number);
    const [endH, endM] = endTimeStr.split(':').map(Number);

    const startDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), startH, startM, 0);
    const endDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), endH, endM, 0);

    if (now < startDt || now > endDt) {
      return res.status(400).json({ success: false, code: 'NO_ACTIVE_SESSION', message: 'Attendance window is currently closed' });
    }

    const sessionDate = now.toISOString().slice(0, 10);

    let [sessions] = await pool.query(
      `SELECT id FROM attendance_sessions WHERE floor_id = ? AND session_date = ?`,
      [floorId, sessionDate]
    );

    let activeSessionId;
    if (sessions.length === 0) {
      const [result] = await pool.query(
        `INSERT INTO attendance_sessions (floor_id, session_date, starts_at, ends_at)
         VALUES (?, ?, ?, ?)`,
        [floorId, sessionDate, startDt, endDt]
      );
      activeSessionId = result.insertId;
    } else {
      activeSessionId = sessions[0].id;
    }

    // 2. BLE token must match the current dynamic token generated for this floor
    const [floorRows] = await pool.query('SELECT current_token FROM floors WHERE floor_id = ?', [floorId]);
    if (floorRows.length === 0 || !floorRows[0].current_token) {
      return res.status(403).json({ success: false, code: 'INVALID_TOKEN', message: 'Attendance is not currently active for this floor' });
    }
    
    const isValid = (floorRows[0].current_token === ble_token);

    if (!isValid) {
      return res.status(403).json({ success: false, code: 'INVALID_TOKEN', message: 'Not in range of your floor device. Please go to your assigned floor.' });
    }

    if (rssi < MIN_RSSI) {
      return res.status(403).json({ success: false, code: 'WEAK_SIGNAL', message: 'Move closer to the classroom device' });
    }

    const [students] = await pool.query('SELECT student_code, name FROM students WHERE id = ?', [studentId]);
    if (students.length === 0) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }
    
    const bankCode = students[0].student_code;
    const studentName = students[0].name;

    try {
      await pool.query(
        `INSERT INTO attendance_records (session_id, bank_code, student_name, floor_id, device_uuid, rssi, ble_token_used)
         VALUES (?, ?, ?, ?, '', ?, ?)`,
        [activeSessionId, bankCode, studentName, floorId, rssi, ble_token]
      );
    } catch (dbErr) {
      if (dbErr.code === 'ER_DUP_ENTRY') {
        return res.status(409).json({ success: false, code: 'ALREADY_MARKED', message: 'Attendance already marked for this session' });
      }
      throw dbErr;
    }

    return res.status(201).json({ success: true, message: 'Attendance marked successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/attendance/session/:id/records
// ------------------------------------------------------------
router.get('/session/:id/records', verifyFloorLeader, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT bank_code as student_code, student_name as name, rssi, marked_at
       FROM attendance_records
       WHERE session_id = ? AND floor_id = ?
       ORDER BY marked_at ASC`,
      [req.params.id, req.leader.floor_id]
    );
    return res.json({ success: true, records: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/attendance/gateway-sync
// ------------------------------------------------------------
router.post('/gateway-sync', async (req, res) => {
  try {
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== process.env.GATEWAY_API_KEY) {
      return res.status(401).json({ success: false, message: 'Unauthorized Gateway' });
    }

    const { student_id, device_id, floor_id, rssi, token } = req.body;
    if (!student_id || !device_id || !floor_id || !token) {
      return res.status(400).json({ success: false, message: 'Missing fields' });
    }

    const [students] = await pool.query('SELECT student_code, name FROM students WHERE name = ?', [student_id]);
    if (students.length === 0) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }
    const bankCode = students[0].student_code;
    const studentName = students[0].name;

    const sessionDate = new Date().toISOString().slice(0, 10);
    const [sessions] = await pool.query(
      `SELECT id FROM attendance_sessions WHERE floor_id = ? AND session_date = ?`,
      [floor_id, sessionDate]
    );

    let activeSessionId;
    if (sessions.length === 0) {
      const [settingsRows] = await pool.query('SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ("DAILY_START_TIME", "DAILY_END_TIME")');
      let startTimeStr = '21:00';
      let endTimeStr = '21:30';
      for (const row of settingsRows) {
        if (row.setting_key === 'DAILY_START_TIME') startTimeStr = row.setting_value;
        if (row.setting_key === 'DAILY_END_TIME') endTimeStr = row.setting_value;
      }

      const now = new Date();
      const [startH, startM] = startTimeStr.split(':').map(Number);
      const [endH, endM] = endTimeStr.split(':').map(Number);

      const startDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), startH, startM, 0);
      const endDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), endH, endM, 0);
      
      const [result] = await pool.query(
        `INSERT INTO attendance_sessions (floor_id, session_date, starts_at, ends_at)
         VALUES (?, ?, ?, ?)`,
        [floor_id, sessionDate, startDt, endDt]
      );
      activeSessionId = result.insertId;
    } else {
      activeSessionId = sessions[0].id;
    }

    try {
      await pool.query(
        `INSERT INTO attendance_records (session_id, bank_code, student_name, floor_id, device_uuid, rssi, ble_token_used)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [activeSessionId, bankCode, studentName, floor_id, device_id, rssi || -50, token]
      );
    } catch (dbErr) {
      if (dbErr.code === 'ER_DUP_ENTRY') {
        return res.status(409).json({ success: false, message: 'Already marked' });
      }
      throw dbErr;
    }

    return res.json({ success: true, message: 'Synced' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/attendance/live
// ------------------------------------------------------------
router.get('/live', verifyAdminOrFloorLeader, async (req, res) => {
  try {
    let floorId = null;
    if (req.leader) {
      floorId = req.leader.floor_id;
    }

    let queryParams = [];
    const sessionDate = new Date().toISOString().slice(0, 10);
    
    let sessionsQuery = 'SELECT id FROM attendance_sessions WHERE session_date = ?';
    let sessionsParams = [sessionDate];
    
    if (floorId !== null) {
      sessionsQuery += ' AND floor_id = ?';
      sessionsParams.push(floorId);
    }
    
    const [sessions] = await pool.query(sessionsQuery, sessionsParams);

    if (sessions.length === 0) {
      return res.json({ success: true, records: [] });
    }

    const sessionIds = sessions.map(s => s.id);

    let recordsQuery = `
       SELECT ar.bank_code as student_code, ar.student_name as name, ar.rssi, ar.marked_at, f.floor_name
       FROM attendance_records ar
       LEFT JOIN floors f ON ar.floor_id = f.floor_id
       WHERE ar.session_id IN (?)
    `;
    let recordsParams = [sessionIds];
    
    if (floorId !== null) {
      recordsQuery += ' AND ar.floor_id = ?';
      recordsParams.push(floorId);
    }
    
    recordsQuery += ' ORDER BY ar.marked_at DESC';

    const [rows] = await pool.query(recordsQuery, recordsParams);

    return res.json({ success: true, records: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/attendance/export
// ------------------------------------------------------------
router.get('/export', verifyAdminOrFloorLeader, async (req, res) => {
  try {
    const sessionDate = req.query.date || new Date().toISOString().slice(0, 10);
    
    const query = `
       SELECT ar.bank_code as student_code, ar.student_name as name, f.floor_name, ar.marked_at
       FROM attendance_records ar
       LEFT JOIN floors f ON ar.floor_id = f.floor_id
       JOIN attendance_sessions ses ON ar.session_id = ses.id
       WHERE ses.session_date = ?
       ORDER BY ar.marked_at DESC
    `;
    
    const [rows] = await pool.query(query, [sessionDate]);
    
    const headers = ['Student Code', 'Name', 'Floor', 'Time Marked'];
    const csvRows = [headers.join(',')];
    
    for (const row of rows) {
      const dateStr = new Date(row.marked_at).toLocaleString();
      const name = `"${(row.name || '').replace(/"/g, '""')}"`;
      const floor = `"${(row.floor_name || '').replace(/"/g, '""')}"`;
      
      csvRows.push([row.student_code, name, floor, `"${dateStr}"`].join(','));
    }
    
    const csvData = csvRows.join('\n');
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="attendance_${sessionDate}.csv"`);
    
    return res.send(csvData);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error during export' });
  }
});

module.exports = router;
