const { body } = require('express-validator');

// Feedback Validation
exports.validateFeedback = [
  body('target_type')
    .trim()
    .notEmpty().withMessage('Target type is required')
    .isIn(['lab', 'test', 'order', 'system']).withMessage('Target type must be lab, test, order, or system'),

  body('target_id')
    .optional()
    .trim()
    .if(body('target_type').not().equals('system'))
    .notEmpty().withMessage('Target ID is required for non-system feedback')
    .isMongoId().withMessage('Invalid target ID format'),

  body('rating')
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),

  body('message')
    .optional()
    .trim()
    .isLength({ max: 1000 }).withMessage('Message must not exceed 1000 characters'),

  body('is_anonymous')
    .optional()
    .isBoolean().withMessage('is_anonymous must be true or false')
];