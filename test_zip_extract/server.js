process.env.TZ = 'Asia/Kolkata';
require('dotenv').config();
require('./services/cron');
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const rebindRoutes = require('./routes/rebind');
const attendanceRoutes = require('./routes/attendance');
const adminRoutes = require('./routes/admin');
const studentsRoutes = require('./routes/students');
const floorsRoutes = require('./routes/floors');
const esp32Routes = require('./routes/esp32');

const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-hsh-auth-token']
}));
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'hostel-attendance-backend' });
});

app.use('/api/auth', authRoutes);
app.use('/api/rebind', rebindRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/students', studentsRoutes);
app.use('/api/floors', floorsRoutes);
app.use('/api/esp32', esp32Routes);

// Fallback error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ success: false, message: 'Unexpected server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Attendance backend running on http://localhost:${PORT}`);
});
