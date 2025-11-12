const { body, param, query } = require('express-validator');

// Request Tests Validation
exports.validateRequestTests = [
  body('owner_id')
    .trim()
    .notEmpty().withMessage('Lab ID is required')
    .isMongoId().withMessage('Invalid lab ID format'),
  
  body('test_ids')
    .isArray({ min: 1 }).withMessage('At least one test is required'),
  
  body('test_ids.*')
    .isMongoId().withMessage('Invalid test ID format'),
  
  body('doctor_id')
    .optional()
    .trim()
    .isMongoId().withMessage('Invalid doctor ID format'),
  
  body('is_urgent')
    .optional()
    .isBoolean().withMessage('is_urgent must be true or false'),
  
  body('remarks')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('Remarks must not exceed 500 characters')
];

// Login Validation
exports.validateLogin = [
  body('username')
    .trim()
    .notEmpty().withMessage('Username is required')
    .isLength({ min: 3, max: 100 }).withMessage('Username must be 3-100 characters')
    .matches(/^[a-zA-Z0-9._@-]+$/).withMessage('Username contains invalid characters'),
  
  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 6, max: 100 }).withMessage('Password must be 6-100 characters')
];

// Change Password Validation
exports.validateChangePassword = [
  body('currentPassword')
    .notEmpty().withMessage('Current password is required'),
  
  body('newPassword')
    .notEmpty().withMessage('New password is required')
    .isLength({ min: 8 }).withMessage('New password must be at least 8 characters')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/).withMessage('Password must contain uppercase, lowercase, and number')
];

// Get Order By ID Validation
exports.validateOrderId = [
  param('orderId')
    .trim()
    .isMongoId().withMessage('Invalid order ID format')
];

// Get Invoice By ID Validation
exports.validateInvoiceId = [
  param('invoiceId')
    .trim()
    .isMongoId().withMessage('Invalid invoice ID format')
];

// Get Lab Tests Validation
exports.validateLabId = [
  param('labId')
    .trim()
    .isMongoId().withMessage('Invalid lab ID format')
];

// Mark Notification as Read Validation
exports.validateNotificationId = [
  param('notificationId')
    .trim()
    .isMongoId().withMessage('Invalid notification ID format')
];

// Search Doctors Validation
exports.validateSearchDoctors = [
  query('search')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 }).withMessage('Search term must be 2-100 characters')
];

// Get Orders Query Validation
exports.validateGetOrders = [
  query('status')
    .optional()
    .trim()
    .isIn(['pending', 'processing', 'completed']).withMessage('Invalid status value')
];
