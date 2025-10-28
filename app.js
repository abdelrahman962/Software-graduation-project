const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const cronJobs = require('./cronJobs');
dotenv.config();
connectDB();

const app = express();
app.use(express.json());

// Routes
app.use('/api/staff', require('./routes/staffRoutes'));
// Add other routes: patientRoutes, testRoutes, deviceRoutes, etc.

// Error Middleware
app.use((err, req, res, next) => {
  res.status(500).json({ message: err.message });
});

module.exports = app;
