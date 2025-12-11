const express = require("express");
const router = express.Router();
const doctorController = require("../controllers/doctorController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const doctorValidator = require("../validators/doctorValidator");
const { validateRequest } = require("../middleware/validationMiddleware");

// ==================== AUTHENTICATION ====================
/**
 * @route   POST /api/doctor/login
 * @desc    Doctor login
 * @access  Public
 */
router.post("/login", ...doctorValidator.validateLogin, validateRequest, doctorController.loginDoctor);

// All routes below require auth and Doctor role
router.use(authMiddleware);
router.use(roleMiddleware(["Doctor"]));

// ==================== DASHBOARD ====================
/**
 * @route   GET /api/doctor/dashboard
 * @desc    Get doctor dashboard (stats, recent orders, notifications)
 * @access  Private (Doctor)
 */
router.get("/dashboard", doctorController.getDashboard);

// ==================== NOTIFICATIONS ====================
/**
 * @route   GET /api/doctor/notifications
 * @desc    Get all notifications for doctor
 * @access  Private (Doctor)
 */
router.get("/notifications", doctorController.getNotifications);

/**
 * @route   GET /api/doctor/notifications/unread-count
 * @desc    Get count of unread notifications
 * @access  Private (Doctor)
 */
router.get("/notifications/unread-count", doctorController.getUnreadNotificationsCount);

// ==================== LAB & TEST INFORMATION ====================
/**
 * @route   GET /api/doctor/labs
 * @desc    Get all available labs
 * @access  Private (Doctor)
 */
router.get("/labs", doctorController.getAvailableLabs);

/**
 * @route   GET /api/doctor/labs/:lab_id/tests
 * @desc    Get available tests for a specific lab
 * @access  Private (Doctor)
 */
router.get("/labs/:lab_id/tests", doctorController.getLabTests);

// ==================== PATIENT MANAGEMENT ====================
/**
 * @route   GET /api/doctor/patients/search
 * @desc    Search for patients by name, email, or ID
 * @access  Private (Doctor)
 */
router.get("/patients/search", doctorController.searchPatients);

/**
 * @route   GET /api/doctor/patients
 * @desc    Get list of patients under doctor's care
 * @access  Private (Doctor)
 */
router.get("/patients", doctorController.getPatients);

/**
 * @route   GET /api/doctor/patient/:patient_id
 * @desc    Get patient details
 * @access  Private (Doctor)
 */
router.get("/patient/:patient_id", doctorController.getPatientDetails);

/**
 * @route   GET /api/doctor/patient/:patient_id/history
 * @desc    View patient's complete test history
 * @access  Private (Doctor)
 */
router.get("/patient/:patient_id/history", doctorController.getPatientTestHistory);

// ==================== PATIENT REPORTS ====================
/**
 * @route   GET /api/doctor/patient-orders
 * @desc    Get all patient orders with results summary (for doctor dashboard)
 * @access  Private (Doctor)
 */
router.get("/patient-orders", doctorController.getPatientOrdersWithResults);

/**
 * @route   GET /api/doctor/order/:order_id/results
 * @desc    Get detailed results for a specific order
 * @access  Private (Doctor)
 */
router.get("/order/:order_id/results", doctorController.getOrderResults);

// ==================== TEST ORDERING ====================
/**
 * @route   POST /api/doctor/request-test
 * @desc    Request tests for a patient
 * @access  Private (Doctor)
 */
router.post("/request-test", ...doctorValidator.validateRequestTest, validateRequest, doctorController.requestTestForPatient);

/**
 * @route   POST /api/doctor/order/:order_id/urgent
 * @desc    Mark existing order as urgent
 * @access  Private (Doctor)
 */
router.post("/order/:order_id/urgent", ...doctorValidator.validateMarkUrgent, validateRequest, doctorController.markTestUrgent);

// ==================== FEEDBACK ====================
/**
 * @route   POST /api/doctor/feedback
 * @desc    Submit feedback on labs, tests, or services
 * @access  Private (Doctor)
 */
router.post("/feedback", ...doctorValidator.validateFeedback, validateRequest, doctorController.provideFeedback);

/**
 * @route   GET /api/doctor/feedback
 * @desc    Get doctor's feedback history
 * @access  Private (Doctor)
 */
router.get("/feedback", doctorController.getMyFeedback);

module.exports = router;
