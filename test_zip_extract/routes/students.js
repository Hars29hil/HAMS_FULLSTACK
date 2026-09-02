const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { verifyAdmin, verifyAdminOrFloorLeader } = require('../middleware/auth');
const https = require('https');

router.use(verifyAdminOrFloorLeader);

// Helper function to sync students from AVD API
async function syncStudentsFromApi() {
  try {
    const apiData = await new Promise((resolve, reject) => {
      https.get('https://api.avdvvn.org/public/getStudentBasicDetails', {
        headers: { 'x-hsh-auth-token': 'aF92Kx7QmN4Lp8Vz' }
      }, (response) => {
        let data = '';
        response.on('data', chunk => data += chunk);
        response.on('end', () => {
          try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
        });
      }).on('error', reject);
    });

    if (!apiData || !apiData.data) return;

    for (const extStudent of apiData.data) {
      if (!extStudent.bankCode) continue;
      const canonicalUsername = extStudent.bankCode;
      
      let floorId = 0;
      if (extStudent.room) {
        const roomStr = extStudent.room.toString().trim();
        if (roomStr.length === 5) {
          // e.g. 10000 -> 10th floor
          floorId = parseInt(roomStr.substring(0, 2)) || 0;
        } else if (roomStr.length === 4) {
          // e.g. 9000 -> 9th floor
          floorId = parseInt(roomStr.substring(0, 1)) || 0;
        } else if (roomStr.length === 3) {
          // e.g. 901 -> 9th floor
          floorId = parseInt(roomStr.substring(0, 1)) || 0;
        } else {
          // 1 or 2 digits (e.g. 15) -> Ground floor (0)
          floorId = 0;
        }
      }

      const fullName = `${extStudent.firstName || ''} ${extStudent.lastName || ''}`.trim();
      const phone = extStudent.phone || canonicalUsername;
      const dummyHash = '$2b$10$DKYfBMxGt00SY4/kwh1yeeGZChSF6/9uvosxdWV63dJe.AUQPPME6';
      // Insert if they don't exist yet so Leaders can assign mobile numbers to them
      await pool.query(
        `INSERT IGNORE INTO students (student_code, name, phone_number, password_hash, floor_id)
         VALUES (?, ?, ?, ?, ?)`,
        [canonicalUsername, fullName, phone, dummyHash, floorId]
      );
      
      // Update floor if it changed
      await pool.query('UPDATE students SET floor_id = ? WHERE student_code = ?', [floorId, canonicalUsername]);
    }
  } catch (err) {
    console.error('Error syncing students from API:', err);
  }
}

// ------------------------------------------------------------
// GET /api/students
// ------------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    // Auto-sync students so the list is always fresh from the external API
    await syncStudentsFromApi();

    let query = 'SELECT id AS student_id, name, floor_id, student_code, assigned_mobile FROM students WHERE is_active = TRUE';
    let params = [];
    if (req.leader) {
      query += ' AND floor_id = ?';
      params.push(req.leader.floor_id);
    }
    query += ' ORDER BY name ASC';
    const [students] = await pool.query(query, params);
    return res.json({ success: true, data: students });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// DELETE /api/students/:id
// ------------------------------------------------------------
router.delete('/:id', async (req, res) => {
  try {
    const studentId = req.params.id;
    
    // If it's a leader, ensure they can only delete students on their floor
    if (req.leader) {
      const [students] = await pool.query('SELECT floor_id FROM students WHERE id = ?', [studentId]);
      if (students.length === 0 || students[0].floor_id !== req.leader.floor_id) {
        return res.status(403).json({ success: false, message: 'Not authorized to delete this student' });
      }
    }

    // Hard delete logic - first clean up constraints (rebind_requests)
    await pool.query('DELETE FROM rebind_requests WHERE student_id = ?', [studentId]);
    await pool.query('DELETE FROM students WHERE id = ?', [studentId]);
    
    return res.json({ success: true, message: 'Student deleted successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/students
// ------------------------------------------------------------
router.post('/', async (req, res) => {
  try {
    const { name, student_code, phone_number, floor_id } = req.body;
    if (!name || !student_code || !floor_id) {
       return res.status(400).json({ success: false, message: 'Name, Bank Code, and Floor are required' });
    }
    const dummyHash = '$2b$10$DKYfBMxGt00SY4/kwh1yeeGZChSF6/9uvosxdWV63dJe.AUQPPME6'; // dummy 'password123'
    
    // Check if leader and enforce their floor id
    let finalFloorId = floor_id;
    if (req.leader) {
      finalFloorId = req.leader.floor_id;
    }

    await pool.query(
      `INSERT INTO students (student_code, name, phone_number, password_hash, floor_id)
       VALUES (?, ?, ?, ?, ?)`,
      [student_code, name, phone_number || null, dummyHash, finalFloorId]
    );
    return res.json({ success: true, message: 'Student added successfully' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
        return res.status(400).json({ success: false, message: 'Student with this Bank Code already exists' });
    }
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// POST /api/students/sync
// ------------------------------------------------------------
router.post('/sync', async (req, res) => {
  try {
    await syncStudentsFromApi();
    return res.json({ success: true, message: 'Students synced successfully from External API' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// PUT /api/students/:id/room
// ------------------------------------------------------------
router.put('/:id/room', async (req, res) => {
  try {
    const studentId = req.params.id;
    const { floor_id } = req.body;
    
    // floor_id can be null or empty string to unassign
    const newFloorId = (floor_id && floor_id !== 'null') ? floor_id : null;
    
    await pool.query('UPDATE students SET floor_id = ? WHERE id = ?', [newFloorId, studentId]);
    return res.json({ success: true, message: 'Floor assigned successfully' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ------------------------------------------------------------
// PUT /api/students/:id/mobile
// ------------------------------------------------------------
router.put('/:id/mobile', async (req, res) => {
  try {
    const studentId = req.params.id;
    const { assigned_mobile } = req.body;
    
    // assigned_mobile can be null or empty string to unassign
    const newMobile = (assigned_mobile && assigned_mobile.trim() !== '') ? assigned_mobile.trim() : null;
    
    console.log(`Assigning mobile ${newMobile} to student ID ${studentId}`);
    
    const [result] = await pool.query('UPDATE students SET assigned_mobile = ? WHERE id = ?', [newMobile, studentId]);
    
    if (result.affectedRows === 0) {
      console.log(`Failed to assign mobile: Student ID ${studentId} not found in database.`);
      return res.status(404).json({ success: false, message: `Student ID ${studentId} not found in database` });
    }

    return res.json({ success: true, message: 'Mobile assigned successfully' });
  } catch (err) {
    console.error('Error assigning mobile:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
