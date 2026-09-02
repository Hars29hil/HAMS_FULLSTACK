const cron = require('node-cron');
const pool = require('../config/db');
const admin = require('../config/firebase');
const crypto = require('crypto');

function generateRandomToken() {
  return crypto.randomBytes(3).toString('hex').toUpperCase(); // 6 char random token
}

async function sendPushNotification(tokens, title, body) {
  if (!tokens || tokens.length === 0) return;
  
  const message = {
    notification: { title, body },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    console.log(`Cron Push Notification sent: ${response.successCount} successes`);
  } catch (error) {
    console.error('Error sending cron push notifications:', error);
  }
}

async function getUnmarkedStudentTokens() {
  const query = `
    SELECT fcm_token FROM students 
    WHERE fcm_token IS NOT NULL 
    AND id NOT IN (
      SELECT student_id FROM attendance_records WHERE DATE(marked_at) = CURDATE()
    )
  `;
  const [rows] = await pool.query(query);
  return rows.map(r => r.fcm_token).filter(t => t);
}

async function getAllStudentTokens() {
  const query = `SELECT fcm_token FROM students WHERE fcm_token IS NOT NULL`;
  const [rows] = await pool.query(query);
  return rows.map(r => r.fcm_token).filter(t => t);
}

// Run every minute at 0 seconds
cron.schedule('* * * * *', async () => {
  try {
    const [settingsRows] = await pool.query(
      'SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ("DAILY_START_TIME", "DAILY_END_TIME")'
    );
    
    let startTimeStr = '21:00';
    let endTimeStr = '21:30';
    for (const row of settingsRows) {
      if (row.setting_key === 'DAILY_START_TIME') startTimeStr = row.setting_value;
      if (row.setting_key === 'DAILY_END_TIME') endTimeStr = row.setting_value;
    }

    if (startTimeStr === endTimeStr) {
      // Attendance is manually stopped, do nothing.
      return;
    }

    const now = new Date();
    // Strip seconds and milliseconds for exact minute matching
    now.setSeconds(0, 0);
    const nowTime = now.getTime();

    const [startH, startM] = startTimeStr.split(':').map(Number);
    const [endH, endM] = endTimeStr.split(':').map(Number);
    
    const startDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), startH, startM, 0);
    const endDt = new Date(now.getFullYear(), now.getMonth(), now.getDate(), endH, endM, 0);
    
    const startTimeMs = startDt.getTime();
    const endTimeMs = endDt.getTime();
    const tenMinsBeforeEndMs = endTimeMs - (10 * 60000);

    // 1. At Start Time
    if (nowTime === startTimeMs) {
      // Generate tokens for all floors
      const [floors] = await pool.query('SELECT floor_id FROM floors');
      for (const floor of floors) {
        const token = generateRandomToken();
        await pool.query('UPDATE floors SET current_token = ? WHERE floor_id = ?', [token, floor.floor_id]);
      }
      console.log('Generated new attendance tokens for all floors.');

      const tokens = await getAllStudentTokens();
      await sendPushNotification(tokens, "Attendance is Started! ⏰", "The attendance window is now open. Please mark your attendance.");
      return;
    }

    // 2. At End Time
    if (nowTime === endTimeMs) {
      // Clear tokens for all floors
      await pool.query('UPDATE floors SET current_token = NULL');
      console.log('Cleared attendance tokens for all floors.');

      const tokens = await getAllStudentTokens();
      await sendPushNotification(tokens, "Attendance is Closed 🔒", "The attendance window has ended.");
      return;
    }

    // 3. 10 Minutes before End Time
    if (nowTime === tenMinsBeforeEndMs) {
      const tokens = await getUnmarkedStudentTokens();
      await sendPushNotification(tokens, "Only 10 minutes left! ⏳", "Attendance closes soon. Go and mark your attendance now!");
      return;
    }

    // 4. Every 10 Minutes between start and 10-minutes-before-end
    if (nowTime > startTimeMs && nowTime < tenMinsBeforeEndMs) {
      const diffMinutes = Math.floor((nowTime - startTimeMs) / 60000);
      if (diffMinutes > 0 && diffMinutes % 10 === 0) {
        const tokens = await getUnmarkedStudentTokens();
        await sendPushNotification(tokens, "Reminder: Mark Attendance ⚠️", "You haven't marked your attendance yet. Go and do your attendance!");
      }
    }

  } catch (err) {
    console.error('Error in cron job:', err);
  }
});

console.log('Push notification cron service started.');
