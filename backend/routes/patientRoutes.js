const express = require('express');
const router = express.Router();
const patientController = require('../controllers/patientController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const { loginLimiter } = require('../middleware/rateLimitMiddleware');

// ==================== AUTHENTICATION ROUTES ====================

/**
 * @route   POST /api/patient/login
 * @desc    Patient login
 * @access  Public
 */
router.post('/login', loginLimiter, patientController.login);

/**
 * @route   GET /api/patient/profile
 * @desc    Get patient profile
 * @access  Private (Patient)
 */
router.get('/profile', authMiddleware, roleMiddleware(['patient']), patientController.getProfile);

/**
 * @route   PUT /api/patient/profile
 * @desc    Update patient profile
 * @access  Private (Patient)
 */
router.put('/profile', authMiddleware, roleMiddleware(['patient']), patientController.updateProfile);

/**
 * @route   PUT /api/patient/change-password
 * @desc    Change password
 * @access  Private (Patient)
 */
router.put('/change-password', authMiddleware, roleMiddleware(['patient']), patientController.changePassword);

// ==================== TEST ORDER ROUTES ====================

/**
 * @route   GET /api/patient/orders
 * @desc    Get all patient orders
 * @access  Private (Patient)
 */
router.get('/orders', authMiddleware, roleMiddleware(['patient']), patientController.getMyOrders);

/**
 * @route   GET /api/patient/orders/:orderId
 * @desc    Get single order details
 * @access  Private (Patient)
 */
router.get('/orders/:orderId', authMiddleware, roleMiddleware(['patient']), patientController.getOrderById);

/**
 * @route   POST /api/patient/request-tests
 * @desc    Request new tests (self-request)
 * @access  Private (Patient)
 */
router.post('/request-tests', authMiddleware, roleMiddleware(['patient']), patientController.requestTests);

// ==================== TEST RESULTS ROUTES ====================

/**
 * @route   GET /api/patient/results
 * @desc    Get all test results
 * @access  Private (Patient)
 */
router.get('/results', authMiddleware, roleMiddleware(['patient']), patientController.getMyResults);

/**
 * @route   GET /api/patient/results/:detailId
 * @desc    Get result for specific test
 * @access  Private (Patient)
 */
router.get('/results/:detailId', authMiddleware, roleMiddleware(['patient']), patientController.getResultById);

/**
 * @route   GET /api/patient/results/:detailId/download
 * @desc    Download result
 * @access  Private (Patient)
 */
router.get('/results/:detailId/download', authMiddleware, roleMiddleware(['patient']), patientController.downloadResult);

// ==================== MEDICAL HISTORY ROUTES ====================

/**
 * @route   GET /api/patient/history
 * @desc    Get medical test history
 * @access  Private (Patient)
 */
router.get('/history', authMiddleware, roleMiddleware(['patient']), patientController.getTestHistory);

// ==================== NOTIFICATION ROUTES ====================

/**
 * @route   GET /api/patient/notifications
 * @desc    Get all notifications
 * @access  Private (Patient)
 */
router.get('/notifications', authMiddleware, roleMiddleware(['patient']), patientController.getNotifications);

/**
 * @route   PUT /api/patient/notifications/:notificationId/read
 * @desc    Mark notification as read
 * @access  Private (Patient)
 */
router.put('/notifications/:notificationId/read', authMiddleware, roleMiddleware(['patient']), patientController.markNotificationAsRead);

// ==================== INVOICE ROUTES ====================

/**
 * @route   GET /api/patient/invoices
 * @desc    Get all invoices
 * @access  Private (Patient)
 */
router.get('/invoices', authMiddleware, roleMiddleware(['patient']), patientController.getMyInvoices);

/**
 * @route   GET /api/patient/invoices/:invoiceId
 * @desc    Get single invoice
 * @access  Private (Patient)
 */
router.get('/invoices/:invoiceId', authMiddleware, roleMiddleware(['patient']), patientController.getInvoiceById);

// ==================== LABS & TESTS ROUTES ====================

/**
 * @route   GET /api/patient/labs
 * @desc    Get available labs
 * @access  Private (Patient)
 */
router.get('/labs', authMiddleware, roleMiddleware(['patient']), patientController.getAvailableLabs);

/**
 * @route   GET /api/patient/labs/:labId/tests
 * @desc    Get available tests for a lab
 * @access  Private (Patient)
 */
router.get('/labs/:labId/tests', authMiddleware, roleMiddleware(['patient']), patientController.getLabTests);

// ==================== DASHBOARD ROUTE ====================

/**
 * @route   GET /api/patient/dashboard
 * @desc    Get patient dashboard
 * @access  Private (Patient)
 */
router.get('/dashboard', authMiddleware, roleMiddleware(['patient']), patientController.getDashboard);

module.exports = router;
