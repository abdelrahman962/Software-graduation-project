const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const cronJobs = require('./cronJobs');
const mongoSanitize = require('express-mongo-sanitize');

dotenv.config();

// Validate required environment variables
const requiredEnvVars = ['MONGO_URI', 'JWT_SECRET'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  console.error(`❌ Missing required environment variables: ${missingEnvVars.join(', ')}`);
  console.error('Please check your .env file');
  process.exit(1);
}

connectDB();

const app = express();

// Security middleware
const helmet = require('helmet');
const cors = require('cors');

app.use(helmet()); // Add security headers
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:5173',
  credentials: true
}));

app.use(express.json());

// NoSQL Injection Protection - sanitize all user input
app.use(mongoSanitize({
  replaceWith: '_',
  onSanitize: ({ req, key }) => {
    console.warn(`⚠️ Sanitized potentially malicious input: ${key}`);
  }
}));

// Routes
app.use('/api/public', require('./routes/publicRoutes')); // Public endpoints (no auth)
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/owner', require('./routes/ownerRoutes'));
app.use('/api/patient', require('./routes/patientRoutes'));
app.use('/api/staff', require('./routes/staffRoutes'));
app.use('/api/doctor', require('./routes/doctorRoutes'));
app.use('/api/invoice', require('./routes/invoiceRoutes')); // Invoice & payment endpoints
// Error Middleware
app.use((err, req, res, next) => {
  res.status(500).json({ message: err.message });
});

module.exports = app;
