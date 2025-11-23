const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./config/db');
const cronJobs = require('./cronJobs');
const logger = require('./utils/logger');
// const mongoSanitize = require('express-mongo-sanitize');

dotenv.config();

// Validate required environment variables
const requiredEnvVars = ['MONGO_URI', 'JWT_SECRET'];
const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  logger.error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
  logger.error('Please check your .env file');
  process.exit(1);
}

connectDB();

const app = express();

// Security middleware
const helmet = require('helmet');
const cors = require('cors');

app.use(helmet()); // Add security headers
app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000', /^http:\/\/localhost:\d+$/],
  credentials: true
}));

app.use(express.json());

// HTTP request logging
app.use(logger.httpLogger);

// NoSQL Injection Protection - sanitize all user input
// Temporarily disabled to fix "Cannot set property query" error
// app.use(mongoSanitize({
//   replaceWith: '_'
// }));

// Routes
app.use('/api/branches', require('./routes/labBranchRoutes')); // Lab branches & public endpoints (merged)
app.use('/api/public', require('./routes/publicRoutes')); // Legacy public routes (kept for backwards compatibility)
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/owner', require('./routes/ownerRoutes'));
app.use('/api/patient', require('./routes/patientRoutes'));
app.use('/api/staff', require('./routes/staffRoutes'));
app.use('/api/doctor', require('./routes/doctorRoutes'));
app.use('/api/invoice', require('./routes/invoiceRoutes')); // Invoice & payment endpoints

// Error Middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({ message: err.message });
});

module.exports = app;
