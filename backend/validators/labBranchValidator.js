const { body, query, validationResult } = require('express-validator');

exports.validateBranchCreation = [
  body('branch_name')
    .trim()
    .notEmpty()
    .withMessage('Branch name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Branch name must be between 2 and 100 characters'),
  
  body('branch_code')
    .trim()
    .notEmpty()
    .withMessage('Branch code is required')
    .matches(/^[A-Z0-9-]+$/)
    .withMessage('Branch code must contain only uppercase letters, numbers, and hyphens'),
  
  body('location.street')
    .trim()
    .notEmpty()
    .withMessage('Street address is required'),
  
  body('location.city')
    .trim()
    .notEmpty()
    .withMessage('City is required'),
  
  body('location.coordinates.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Valid latitude is required (-90 to 90)'),
  
  body('location.coordinates.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Valid longitude is required (-180 to 180)'),
  
  body('contact.phone')
    .trim()
    .notEmpty()
    .withMessage('Phone number is required')
    .matches(/^[\d\s\-\+\(\)]+$/)
    .withMessage('Invalid phone number format'),
  
  body('contact.email')
    .optional()
    .isEmail()
    .withMessage('Invalid email format'),
  
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  }
];

exports.validateBranchUpdate = [
  body('branch_name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Branch name must be between 2 and 100 characters'),
  
  body('location.coordinates.latitude')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('Valid latitude is required (-90 to 90)'),
  
  body('location.coordinates.longitude')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('Valid longitude is required (-180 to 180)'),
  
  body('contact.email')
    .optional()
    .isEmail()
    .withMessage('Invalid email format'),
  
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  }
];

exports.validateNearestSearch = [
  query('latitude')
    .notEmpty()
    .withMessage('Latitude is required')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Valid latitude is required (-90 to 90)'),
  
  query('longitude')
    .notEmpty()
    .withMessage('Longitude is required')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Valid longitude is required (-180 to 180)'),
  
  query('maxDistance')
    .optional()
    .isFloat({ min: 1, max: 500 })
    .withMessage('Max distance must be between 1 and 500 km'),
  
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  }
];
