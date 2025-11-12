const express = require('express');
const router = express.Router();
const publicController = require('../controllers/publicController');
const { loginLimiter } = require('../middleware/rateLimitMiddleware');

/**
 * @route   POST /api/public/submit-registration
 * @desc    Patient submits registration form with personal info and test orders (no account needed)
 * @access  Public
 */
router.post('/submit-registration', loginLimiter, publicController.submitRegistration);

/**
 * @route   GET /api/public/labs
 * @desc    Get list of available labs
 * @access  Public
 */
router.get('/labs', publicController.getAvailableLabs);

/**
 * @route   GET /api/public/labs/:labId/tests
 * @desc    Get available tests for a specific lab
 * @access  Public
 */
router.get('/labs/:labId/tests', publicController.getLabTests);

module.exports = router;
