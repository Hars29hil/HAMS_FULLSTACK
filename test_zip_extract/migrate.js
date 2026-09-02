const pool = require('./config/db');

async function migrate() {
  try {
    console.log('Adding fcm_token column to students table...');
    await pool.query('ALTER TABLE students ADD COLUMN fcm_token VARCHAR(255) DEFAULT NULL;');
    console.log('Migration successful!');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      console.log('Column fcm_token already exists. Migration skipped.');
    } else {
      console.error('Migration failed:', err);
    }
  } finally {
    process.exit(0);
  }
}

migrate();
