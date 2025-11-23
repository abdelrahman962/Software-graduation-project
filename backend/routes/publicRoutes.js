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

/**
 * @route   GET /api/public/branches/all
 * @desc    Get all available lab branches with pagination
 * @access  Public
 */
router.get('/branches/all', publicController.getAllAvailableBranches);

/**
 * @route   GET /api/public/branches/nearest
 * @desc    Find nearest lab branches by GPS coordinates
 * @access  Public
 */
router.get('/branches/nearest', publicController.findNearestBranches);

/**
 * @route   GET /api/public/branches/search
 * @desc    Search branches by city, state, or services
 * @access  Public
 */
router.get('/branches/search', publicController.searchBranches);

/**
 * @route   GET /api/public/register/verify/:token
 * @desc    Verify registration token and get order details
 * @access  Public
 */
router.get('/register/verify/:token', publicController.verifyRegistrationToken);

/**
 * @route   POST /api/public/register/complete
 * @desc    Complete patient registration using token
 * @access  Public
 */
router.post('/register/complete', publicController.completeRegistration);

module.exports = router;
