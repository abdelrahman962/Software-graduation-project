const express = require('express');
const router = express.Router();
const ownerController = require('../controllers/ownerController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const labOwnerController=require('../controllers/ownerController');
// ==================== AUTHENTICATION ROUTES ====================

/**
 * @route   POST /api/owner/login
 * @desc    Lab Owner login
 * @access  Public
 */
router.post('/login', ownerController.login);

// Lab Owner Request Access
// POST /api/owner/request-access
router.post('/request-access', labOwnerController.requestAccess);



/**
 * @route   GET /api/owner/profile
 * @desc    Get owner profile
 * @access  Private (Owner)
 */
router.get('/profile', authMiddleware, roleMiddleware(['owner']), ownerController.getProfile);

/**
 * @route   PUT /api/owner/profile
 * @desc    Update owner profile
 * @access  Private (Owner)
 */
router.put('/profile', authMiddleware, roleMiddleware(['owner']), ownerController.updateProfile);

/**
 * @route   PUT /api/owner/change-password
 * @desc    Change password
 * @access  Private (Owner)
 */
router.put('/change-password', authMiddleware, roleMiddleware(['owner']), ownerController.changePassword);

// ==================== STAFF MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/staff
 * @desc    Get all staff members
 * @access  Private (Owner)
 */
router.get('/staff', authMiddleware, roleMiddleware(['owner']), ownerController.getAllStaff);

/**
 * @route   GET /api/owner/staff/:staffId
 * @desc    Get single staff member
 * @access  Private (Owner)
 */
router.get('/staff/:staffId', authMiddleware, roleMiddleware(['owner']), ownerController.getStaffById);

/**
 * @route   POST /api/owner/staff
 * @desc    Add new staff member
 * @access  Private (Owner)
 */
router.post('/staff', authMiddleware, roleMiddleware(['owner']), ownerController.addStaff);

/**
 * @route   PUT /api/owner/staff/:staffId
 * @desc    Update staff member
 * @access  Private (Owner)
 */
router.put('/staff/:staffId', authMiddleware, roleMiddleware(['owner']), ownerController.updateStaff);

/**
 * @route   DELETE /api/owner/staff/:staffId
 * @desc    Delete staff member
 * @access  Private (Owner)
 */
router.delete('/staff/:staffId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteStaff);

// ==================== DEVICE MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/devices
 * @desc    Get all devices
 * @access  Private (Owner)
 */
router.get('/devices', authMiddleware, roleMiddleware(['owner']), ownerController.getAllDevices);

/**
 * @route   POST /api/owner/devices
 * @desc    Add new device
 * @access  Private (Owner)
 */
router.post('/devices', authMiddleware, roleMiddleware(['owner']), ownerController.addDevice);

/**
 * @route   PUT /api/owner/devices/:deviceId
 * @desc    Update device
 * @access  Private (Owner)
 */
router.put('/devices/:deviceId', authMiddleware, roleMiddleware(['owner']), ownerController.updateDevice);

/**
 * @route   DELETE /api/owner/devices/:deviceId
 * @desc    Delete device
 * @access  Private (Owner)
 */
router.delete('/devices/:deviceId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteDevice);

// ==================== TEST MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/tests
 * @desc    Get all tests
 * @access  Private (Owner)
 */
router.get('/tests', authMiddleware, roleMiddleware(['owner']), ownerController.getAllTests);

/**
 * @route   POST /api/owner/tests
 * @desc    Add new test
 * @access  Private (Owner)
 */
router.post('/tests', authMiddleware, roleMiddleware(['owner']), ownerController.addTest);

/**
 * @route   PUT /api/owner/tests/:testId
 * @desc    Update test
 * @access  Private (Owner)
 */
router.put('/tests/:testId', authMiddleware, roleMiddleware(['owner']), ownerController.updateTest);

/**
 * @route   DELETE /api/owner/tests/:testId
 * @desc    Delete test
 * @access  Private (Owner)
 */
router.delete('/tests/:testId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteTest);

// ==================== INVENTORY MANAGEMENT ROUTES ====================

/**
 * @route   GET /api/owner/inventory
 * @desc    Get all inventory items
 * @access  Private (Owner)
 */
router.get('/inventory', authMiddleware, roleMiddleware(['owner']), ownerController.getAllInventory);

/**
 * @route   POST /api/owner/inventory
 * @desc    Add inventory item
 * @access  Private (Owner)
 */
router.post('/inventory', authMiddleware, roleMiddleware(['owner']), ownerController.addInventoryItem);

/**
 * @route   PUT /api/owner/inventory/:itemId
 * @desc    Update inventory item
 * @access  Private (Owner)
 */
router.put('/inventory/:itemId', authMiddleware, roleMiddleware(['owner']), ownerController.updateInventoryItem);

/**
 * @route   DELETE /api/owner/inventory/:itemId
 * @desc    Delete inventory item
 * @access  Private (Owner)
 */
router.delete('/inventory/:itemId', authMiddleware, roleMiddleware(['owner']), ownerController.deleteInventoryItem);

// ==================== DASHBOARD & ANALYTICS ROUTES ====================

/**
 * @route   GET /api/owner/dashboard
 * @desc    Get dashboard statistics
 * @access  Private (Owner)
 */
router.get('/dashboard', authMiddleware, roleMiddleware(['owner']), ownerController.getDashboard);

/**
 * @route   GET /api/owner/reports
 * @desc    Get performance reports
 * @access  Private (Owner)
 */
router.get('/reports', authMiddleware, roleMiddleware(['owner']), ownerController.getReports);

// ==================== NOTIFICATION ROUTES ====================

/**
 * @route   GET /api/owner/notifications
 * @desc    Get all notifications
 * @access  Private (Owner)
 */
router.get('/notifications', authMiddleware, roleMiddleware(['owner']), ownerController.getNotifications);

/**
 * @route   PUT /api/owner/notifications/:notificationId/read
 * @desc    Mark notification as read
 * @access  Private (Owner)
 */
router.put('/notifications/:notificationId/read', authMiddleware, roleMiddleware(['owner']), ownerController.markNotificationAsRead);

/**
 * @route   POST /api/owner/notifications/send
 * @desc    Send notification to staff
 * @access  Private (Owner)
 */
router.post('/notifications/send', authMiddleware, roleMiddleware(['owner']), ownerController.sendNotificationToStaff);

// ==================== ADMIN COMMUNICATION ROUTES ====================

/**
 * @route   POST /api/owner/contact-admin
 * @desc    Send message to admin
 * @access  Private (Owner)
 */
router.post('/contact-admin', authMiddleware, roleMiddleware(['owner']), ownerController.contactAdmin);

// ==================== AUDIT LOG ROUTES ====================

/**
 * @route   GET /api/owner/audit-logs
 * @desc    Get audit logs
 * @access  Private (Owner)
 */
router.get('/audit-logs', authMiddleware, roleMiddleware(['owner']), ownerController.getAuditLogs);

// ==================== PATIENT VIEW ROUTES ====================

/**
 * @route   GET /api/owner/patients
 * @desc    Get all patients (who had tests in this lab)
 * @access  Private (Owner)
 */
router.get('/patients', authMiddleware, roleMiddleware(['owner']), ownerController.getAllPatients);

/**
 * @route   GET /api/owner/patients/:patientId
 * @desc    Get patient details
 * @access  Private (Owner)
 */
router.get('/patients/:patientId', authMiddleware, roleMiddleware(['owner']), ownerController.getPatientById);

module.exports = router;
