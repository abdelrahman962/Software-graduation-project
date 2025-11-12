const { body, param } = require('express-validator');

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

// Upload Result Validation
exports.validateUploadResult = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('result_value')
    .trim()
    .notEmpty().withMessage('Result value is required')
    .isLength({ max: 500 }).withMessage('Result value too long'),
  
  body('remarks')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('Remarks too long')
];

// Collect Sample Validation
exports.validateCollectSample = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('sample_collection_date')
    .optional()
    .isISO8601().withMessage('Invalid date format')
];

// Update Sample Status Validation
exports.validateUpdateSampleStatus = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('status')
    .trim()
    .notEmpty().withMessage('Status is required')
    .isIn(['pending', 'urgent', 'collected', 'in_progress', 'completed'])
    .withMessage('Invalid status value')
];

// Register Patient from Order Validation
exports.validateRegisterPatient = [
  body('order_id')
    .trim()
    .notEmpty().withMessage('Order ID is required')
    .isMongoId().withMessage('Invalid order ID format')
];

// Assign Staff Validation
exports.validateAssignStaff = [
  body('detail_id')
    .trim()
    .notEmpty().withMessage('Detail ID is required')
    .isMongoId().withMessage('Invalid detail ID format'),
  
  body('staff_id')
    .trim()
    .notEmpty().withMessage('Staff ID is required')
    .isMongoId().withMessage('Invalid staff ID format')
];

// Get Order Details Validation
exports.validateOrderId = [
  param('order_id')
    .trim()
    .isMongoId().withMessage('Invalid order ID format')
];
