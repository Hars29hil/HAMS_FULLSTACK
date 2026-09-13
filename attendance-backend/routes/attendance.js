const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { verifyStudent, verifyFloorLeader, verifyAdminOrFloorLeader } = require('../middleware/auth');
const admin = require('../config/firebase');
const crypto = require('crypto');
const { getCurrentIST } = require('../utils/time');

const SECRET_KEY = process.env.AES_SECRET_KEY || 'HAMS_SECRET_KEY!'; // Must be 16 bytes for AES-128

const MIN_RSSI = parseInt(process.env.MIN_RSSI || '-100', 10);

// ------------------------------------------------------------
// GET /api/attendance/my-status
// Returns the student's attendance status for today
// ------------------------------------------------------------
router.get('/my-status', verifyStudent, async (req, res) => {
  try {
    const studentId = req.student.id;
    const floorId = req.student.floor_id || 0; // Default to 0 if undefined to prevent mysql2 crash

    // Fetch all schedules from dynamic table
    const [scheduleRows] = await pool.query(
      'SELECT session_key, start_time, end_time FROM attendance_schedules WHERE is_active = TRUE'
    );
    
    const schedules = {};
    for (const row of scheduleRows) {
      schedules[row.session_key] = { start: row.start_time, end: row.end_time };
    }
    
    const now = getCurrentIST();
    const sessionDate = now.toISOString().slice(0, 10);
    let activeSessionType = null;
    let startTimeStr = '00:00';
    let endTimeStr = '00:00';
    
    for (const [type, times] of Object.entries(schedules)) {
      const [startH, startM] = times.start.split(':').map(Number);
      const [endH, endM] = times.end.split(':').map(Number);
      const startDt = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), startH, startM, 0));
      const endDt = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), endH, endM, 0));
      
      if (startDt.getTime() > endDt.getTime()) {
        // Overnight shift (e.g., 21:00 to 06:00)
        // It's active if now is AFTER startDt OR BEFORE endDt
        if (now >= startDt || now <= endDt) {
          activeSessionType = type;
          startTimeStr = times.start;
          endTimeStr = times.end;
          break;
        }
      } else {
        // Normal shift (e.g., 07:00 to 08:00)
        if (now >= startDt && now <= endDt) {
          activeSessionType = type;
          startTimeStr = times.start;
          endTimeStr = times.end;
          break;
        }
      }
    }

    const attendanceActive = activeSessionType !== null;
    let alreadyMarked = false;
    let bankCode = null;

    const [studentRows] = await pool.query('SELECT student_code FROM students WHERE id = ?', [studentId]);
    if (studentRows.length > 0) {
      bankCode = studentRows[0].student_code;
      
      if (attendanceActive) {
        // 1. Check local database first
        const [sessions] = await pool.query('SELECT id FROM attendance_sessions WHERE session_date = ? AND session_type = ?', [sessionDate, activeSessionType]);
        if (sessions.length > 0) {
          const sessionIds = sessions.map(s => s.id);
          const [localRecords] = await pool.query('SELECT session_id FROM attendance_records WHERE session_id IN (?) AND bank_code = ?', [sessionIds, bankCode]);
          if (localRecords.length > 0) {
            alreadyMarked = true;
          }
        }
      }
    }

    // 2. Fetch from Night Attendance API as fallback (only for night)
    if (!alreadyMarked && bankCode && attendanceActive && activeSessionType === 'night') {
      const https = require('https');
      const apiData = await new Promise((resolve, reject) => {
        https.get(`https://api.avdvvn.org/public/getAttendance?date=${sessionDate}&type=night`, {
          headers: { 'x-hsh-auth-token': 'aF92Kx7QmN4Lp8Vz' }
        }, (response) => {
          let data = '';
          response.on('data', chunk => data += chunk);
          response.on('end', () => {
            try {
              resolve(JSON.parse(data));
            } catch (e) {
              reject(e);
            }
          });
        }).on('error', reject);
      });

      if (apiData && apiData.auth && apiData.data) {
        const match = apiData.data.find(s => String(s.bankCode).replace(/^0+(?=\d)/, '') === String(bankCode).replace(/^0+(?=\d)/, ''));
        if (match) {
          alreadyMarked = true;
        }
      }
    }

    return res.json({
      success: true,
      data: {
        already_marked: alreadyMarked,
        start_time: startTimeStr,
        end_time: endTimeStr,
        attendance_active: attendanceActive,
        active_session_type: activeSessionType,
        schedules: schedules
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
    const type = (req.query.type || 'night').toLowerCase();
    const [rows] = await pool.query('SELECT start_time, end_time FROM attendance_schedules WHERE session_key = ?', [type]);
    let startTimeStr = '00:00';
    let endTimeStr = '00:00';

    if (rows.length > 0) {
      startTimeStr = rows[0].start_time;
      endTimeStr = rows[0].end_time;
    }

    return res.json({
      success: true,
      data: {
        start_time: startTimeStr,
        end_time: endTimeStr
      }
    });
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
    const { startTime, endTime, type } = req.body;
    const sessionType = (type || 'night').toLowerCase();

    if (!startTime || !endTime) {
      return res.status(400).json({ success: false, message: 'Missing startTime or endTime' });
    }

    await pool.query(
      'UPDATE attendance_schedules SET start_time = ?, end_time = ? WHERE session_key = ?',
      [startTime, endTime, sessionType]
    );

    const now = getCurrentIST();
    const [startH, startM] = startTime.split(':').map(Number);
    const [endH, endM] = endTime.split(':').map(Number);

    if (startTime !== endTime) {
      try {
        const [students] = await pool.query('SELECT fcm_token FROM students WHERE fcm_token IS NOT NULL');
        const tokens = students.map(s => s.fcm_token).filter(t => t);

        if (tokens.length > 0) {
          const message = {
            notification: {
              title: `${sessionType} Attendance Update ⏰`,
              body: `The ${sessionType.toLowerCase()} attendance window has been scheduled from ${startTime} to ${endTime}.`,
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

    return res.json({ success: true, message: `${sessionType} schedule updated successfully` });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/attendance/debug-reports
// ------------------------------------------------------------
router.get('/debug-reports', async (req, res) => {
  try {
    const [res1] = await pool.query('DESCRIBE attendance_records');
    const [res2] = await pool.query('DESCRIBE attendance_sessions');
    
    // Test the actual query too
    let err1 = null;
    let counts = null;
    try {
      const [sessionCounts] = await pool.query(`
        SELECT session_type, COUNT(id) as total
        FROM attendance_sessions
        GROUP BY session_type
      `);
      counts = sessionCounts;
    } catch(e) { err1 = e.toString(); }

    return res.json({ success: true, records: res1, sessions: res2, err1, counts });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.toString() });
  }
});

// ------------------------------------------------------------
// GET /api/attendance/debug-sql
// ------------------------------------------------------------
router.get('/debug-sql', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.json({ success: false, message: 'No query' });
    const [rows] = await pool.query(query);
    return res.json({ success: true, data: rows });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.toString() });
  }
});

// ------------------------------------------------------------
// POST /api/attendance/mark
// ------------------------------------------------------------
router.post('/mark', verifyStudent, async (req, res) => {
  try {
    const { rssi } = req.body;
    if (rssi === undefined) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    const floorId = req.student.floor_id || 0;
    const studentId = req.student.id;

    // Fetch all schedules from dynamic table
    const [scheduleRows] = await pool.query(
      'SELECT session_key, start_time, end_time FROM attendance_schedules WHERE is_active = TRUE'
    );
    
    const schedules = {};
    for (const row of scheduleRows) {
      schedules[row.session_key] = { start: row.start_time, end: row.end_time };
    }

    const now = getCurrentIST();
    let activeSessionType = null;
    let startDt = null;
    let endDt = null;
    
    for (const [type, times] of Object.entries(schedules)) {
      const [startH, startM] = times.start.split(':').map(Number);
      const [endH, endM] = times.end.split(':').map(Number);
      const currentStartDt = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), startH, startM, 0));
      const currentEndDt = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), endH, endM, 0));
      
      if (currentStartDt.getTime() > currentEndDt.getTime()) {
        if (now >= currentStartDt || now <= currentEndDt) {
          activeSessionType = type;
          startDt = currentStartDt;
          endDt = currentEndDt;
          break;
        }
      } else {
        if (now >= currentStartDt && now <= currentEndDt) {
          activeSessionType = type;
          startDt = currentStartDt;
          endDt = currentEndDt;
          break;
        }
      }
    }

    if (!activeSessionType) {
      return res.status(400).json({ success: false, code: 'NO_ACTIVE_SESSION', message: 'Attendance window is currently closed' });
    }

    if (rssi < MIN_RSSI) {
      return res.status(403).json({ success: false, code: 'WEAK_SIGNAL', message: 'Move closer to the classroom device' });
    }

    const sessionDate = now.toISOString().slice(0, 10);

    let [sessions] = await pool.query(
      `SELECT id FROM attendance_sessions WHERE floor_id = ? AND session_date = ? AND session_type = ?`,
      [floorId, sessionDate, activeSessionType]
    );

    let activeSessionId;
    if (sessions.length === 0) {
      const [result] = await pool.query(
        `INSERT INTO attendance_sessions (floor_id, session_date, starts_at, ends_at, session_type)
         VALUES (?, ?, ?, ?, ?)`,
        [floorId, sessionDate, startDt, endDt, activeSessionType]
      );
      activeSessionId = result.insertId;
    } else {
      activeSessionId = sessions[0].id;
    }

    const [students] = await pool.query('SELECT student_code, name FROM students WHERE id = ?', [studentId]);
    if (students.length === 0) {
      return res.status(404).json({ success: false, message: 'Student not found' });
    }

    const bankCode = students[0].student_code;
    const studentName = students[0].name;

    // Check if attendance already marked
    const [existing] = await pool.query(
      'SELECT session_id FROM attendance_records WHERE session_id = ? AND bank_code = ?',
      [activeSessionId, bankCode]
    );

    if (existing.length > 0) {
      return res.status(200).json({ success: true, message: 'Attendance already marked for today' });
    }

    // Store in local MySQL DB
    await pool.query(
      `INSERT INTO attendance_records (session_id, bank_code, student_name, floor_id, device_uuid, rssi, ble_token_used)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [activeSessionId, bankCode, studentName, floorId, 'NA', rssi, 'BEACON_ONLY']
    );

    console.log(`[INFO] Attendance marked successfully for ${bankCode}.`);
    return res.status(201).json({ success: true, message: 'Attendance marked successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error: ' + (err.sqlMessage || err.message) });
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



// removed request-token

module.exports = router;
