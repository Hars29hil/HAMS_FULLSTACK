const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const bcrypt = require('bcrypt');
const pool = require('../config/db');
const { verifyAdmin } = require('../middleware/auth');

const CODE_EXPIRY_MIN = parseInt(process.env.REBIND_CODE_EXPIRY_MINUTES || '10', 10);

router.use(verifyAdmin);

// ------------------------------------------------------------
// GET /api/admin/dashboard
// ------------------------------------------------------------
router.get('/dashboard', async (req, res) => {
  try {
    // 1. Total Students
    const [[{ total_students }]] = await pool.query('SELECT COUNT(*) AS total_students FROM students WHERE is_active = TRUE');

    // 2. Present Today
    const [[{ present_today }]] = await pool.query(`
      SELECT COUNT(DISTINCT ar.bank_code) AS present_today 
      FROM attendance_records ar
      JOIN attendance_sessions s ON ar.session_id = s.id
      WHERE s.session_date = CURDATE()
    `);

    // 3. Late Today (Assuming marked_at > starts_at + 15 minutes)
    const [[{ late_today }]] = await pool.query(`
      SELECT COUNT(DISTINCT ar.bank_code) AS late_today 
      FROM attendance_records ar
      JOIN attendance_sessions s ON ar.session_id = s.id
      WHERE s.session_date = CURDATE() AND ar.marked_at > s.starts_at + INTERVAL 15 MINUTE
    `);

    const absent_today = total_students - present_today;

    // 4. Weekly Stats
    const [weeklyStatsRows] = await pool.query(`
      SELECT 
        s.session_date AS date, 
        COUNT(DISTINCT ar.bank_code) AS present,
        SUM(CASE WHEN ar.marked_at > s.starts_at + INTERVAL 15 MINUTE THEN 1 ELSE 0 END) AS late
      FROM attendance_sessions s
      LEFT JOIN attendance_records ar ON s.id = ar.session_id
      WHERE s.session_date >= CURDATE() - INTERVAL 6 DAY
      GROUP BY s.session_date
      ORDER BY s.session_date ASC
    `);

    // Format dates to YYYY-MM-DD string
    const weekly_stats = weeklyStatsRows.map(row => {
      // Create a local date string to avoid timezone shifts
      const dateObj = new Date(row.date);
      const year = dateObj.getFullYear();
      const month = String(dateObj.getMonth() + 1).padStart(2, '0');
      const day = String(dateObj.getDate()).padStart(2, '0');
      return {
        date: `${year}-${month}-${day}`,
        present: row.present,
        late: parseInt(row.late || 0, 10)
      };
    });

    // 5. Floor Status
    // Get global schedule first
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
    const isGlobalActive = now >= startDt && now <= endDt;

    const [floors] = await pool.query('SELECT floor_id, floor_name FROM floors ORDER BY floor_id ASC');
    const floor_status = [];

    for (const f of floors) {
      // Find active session for today for this floor
      const [sessions] = await pool.query(`
        SELECT id, starts_at, ends_at FROM attendance_sessions
        WHERE floor_id = ? AND session_date = CURDATE()
      `, [f.floor_id]);

      let session_status = isGlobalActive ? 'Active' : 'Offline';
      let present_students = 0;
      
      if (sessions.length > 0) {
        const session = sessions[0];
        // If there's a specific session, check its bounds too (in case of manual overrides)
        if (now >= new Date(session.starts_at) && now <= new Date(session.ends_at)) {
          session_status = 'Active';
        } else {
          session_status = 'Offline'; // Session explicitly closed
        }

        const [[{ present_count }]] = await pool.query(`
          SELECT COUNT(DISTINCT bank_code) AS present_count 
          FROM attendance_records 
          WHERE session_id = ?
        `, [session.id]);
        present_students = present_count;
      }

      const [[{ floor_total }]] = await pool.query('SELECT COUNT(*) AS floor_total FROM students WHERE floor_id = ? AND is_active = TRUE', [f.floor_id]);

      floor_status.push({
        floor_name: f.floor_name,
        session_status,
        present_students,
        total_students: floor_total
      });
    }

    return res.json({
      success: true,
      data: {
        total_students,
        present_today,
        late_today: parseInt(late_today || 0, 10),
        absent_today,
        weekly_stats,
        floor_status
      }
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/admin/rebind-requests
// ------------------------------------------------------------
router.get('/rebind-requests', async (req, res) => {
  try {
    const floorId = req.query.floor_id;
    let query = `
       SELECT rr.id, rr.student_id, s.student_code, s.name, s.phone_number,
              rr.new_device_uuid, rr.status, rr.created_at, f.floor_name
       FROM rebind_requests rr
       JOIN students s ON s.id = rr.student_id
       LEFT JOIN floors f ON rr.floor_id = f.floor_id
       WHERE rr.status IN ('pending','code_generated')
    `;
    const params = [];
    
    if (floorId && floorId !== 'ALL') {
      query += ` AND rr.floor_id = ?`;
      params.push(floorId);
    }
    
    query += ` ORDER BY rr.created_at ASC`;
    
    const [rows] = await pool.query(query, params);
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/admin/rebind-requests/:id/generate-code
// ------------------------------------------------------------
router.post('/rebind-requests/:id/generate-code', async (req, res) => {
  try {
    const requestId = req.params.id;

    const [rows] = await pool.query('SELECT * FROM rebind_requests WHERE id = ?', [requestId]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Rebind request not found' });
    }
    const reqRow = rows[0];

    if (reqRow.status === 'completed') {
      return res.status(400).json({ success: false, message: 'Already completed' });
    }

    const code = crypto.randomInt(100000, 999999).toString();
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + CODE_EXPIRY_MIN * 60 * 1000);

    // Using admin.id from token
    await pool.query(
      `UPDATE rebind_requests
       SET status = 'code_generated', code_hash = ?, code_expires_at = ?, generated_by = ?
       WHERE id = ?`,
      [codeHash, expiresAt, req.admin.id, requestId]
    );

    return res.json({
      success: true,
      code,
      expires_at: expiresAt,
      message: 'Read this code to the student. It expires in ' + CODE_EXPIRY_MIN + ' minutes.'
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/admin/esp32/status
// ------------------------------------------------------------
router.get('/esp32/status', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT floor_id, floor_name, device_name, last_seen FROM floors WHERE floor_id >= 0 ORDER BY floor_id ASC');
    
    const floors = rows.map(r => {
      const lastSeen = r.last_seen ? new Date(r.last_seen) : null;
      const now = new Date();
      // Consider online if heartbeat was within the last 2 minutes (120000 ms)
      const isOnline = lastSeen ? (now - lastSeen < 120000) : false;
      return {
        floor_id: r.floor_id,
        floor_name: r.floor_name,
        device_name: r.device_name,
        last_seen: r.last_seen,
        is_online: isOnline
      };
    });

    return res.json({ success: true, data: floors });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/admin/esp32/assign
// ------------------------------------------------------------
router.post('/esp32/assign', async (req, res) => {
  try {
    const { device_name, floor_id } = req.body;
    if (!device_name || floor_id === undefined) {
      return res.status(400).json({ success: false, message: 'Missing device_name or floor_id' });
    }

    // Unassign this device from any other floor first
    await pool.query('UPDATE floors SET device_name = NULL, last_seen = NULL WHERE device_name = ?', [device_name]);

    // Assign to new floor
    await pool.query('UPDATE floors SET device_name = ?, last_seen = NULL WHERE floor_id = ?', [device_name, floor_id]);

    return res.json({ success: true, message: 'ESP-32 assigned successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/admin/esp32/unassign
// ------------------------------------------------------------
router.post('/esp32/unassign', async (req, res) => {
  try {
    const { floor_id } = req.body;
    if (floor_id === undefined) {
      return res.status(400).json({ success: false, message: 'Missing floor_id' });
    }

    await pool.query('UPDATE floors SET device_name = NULL, last_seen = NULL WHERE floor_id = ?', [floor_id]);

    return res.json({ success: true, message: 'ESP-32 unassigned successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// GET /api/admin/sessions
// ------------------------------------------------------------
router.get('/sessions', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM attendance_schedules WHERE is_active = TRUE ORDER BY id ASC');
    return res.json({ success: true, data: rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/admin/sessions
// ------------------------------------------------------------
router.post('/sessions', async (req, res) => {
  try {
    const { session_name, icon_name } = req.body;
    if (!session_name || !icon_name) {
      return res.status(400).json({ success: false, message: 'Missing session_name or icon_name' });
    }
    const session_key = session_name.toLowerCase().replace(/[^a-z0-9]/g, '_');
    
    await pool.query(
      'INSERT INTO attendance_schedules (session_key, session_name, icon_name, start_time, end_time) VALUES (?, ?, ?, ?, ?)',
      [session_key, session_name, icon_name, '00:00', '00:00']
    );
    
    return res.json({ success: true, message: 'Session added successfully' });
  } catch (err) {
    console.error(err);
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ success: false, message: 'A session with this name already exists' });
    }
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// ------------------------------------------------------------
// GET /api/admin/reports
// ------------------------------------------------------------
router.get('/reports', async (req, res) => {
  try {
    // 1. Get total counts per session type
    const [sessionCounts] = await pool.query(`
      SELECT session_type, COUNT(id) as total
      FROM attendance_sessions
      GROUP BY session_type
    `);
    
    const totals = {};
    sessionCounts.forEach(s => {
      if(s.session_type) totals[s.session_type] = s.total;
    });

    // 2. Get attendance counts per student per session type
    const [attendance] = await pool.query(`
      SELECT ar.bank_code, s.session_type, COUNT(*) as attended
      FROM attendance_records ar
      JOIN attendance_sessions s ON ar.session_id = s.id
      GROUP BY ar.bank_code, s.session_type
    `);

    const studentRecords = {};
    attendance.forEach(a => {
      if (!studentRecords[a.bank_code]) {
        studentRecords[a.bank_code] = {};
      }
      if(a.session_type) studentRecords[a.bank_code][a.session_type] = a.attended;
    });

    return res.json({ success: true, totals, studentRecords });
  } catch (err) {
    console.error('Reports Error:', err);
    return res.status(500).json({ success: false, message: err.toString() });
  }
});

router.get('/debug-reports', async (req, res) => {
  try {
    const [res1] = await pool.query('DESCRIBE attendance_records');
    const [res2] = await pool.query('DESCRIBE attendance_sessions');
    return res.json({ success: true, records: res1, sessions: res2 });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.toString() });
  }
});

module.exports = router;
