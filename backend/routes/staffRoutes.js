const express = require("express");
const router = express.Router();
const staffController = require("../controllers/staffController");
const { 
  loginLimiter, 
  resultUploadLimiter, 
  sampleCollectionLimiter 
} = require('../middleware/rateLimitMiddleware');
const inventoryController = require('../controllers/inventoryController');
const { recordStockUsage } = require('../controllers/inventoryController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
const staffValidator = require('../validators/staffValidator');
const { validateRequest } = require('../middleware/validationMiddleware');

// ===============================
// 🧩 Authentication
// ===============================
router.post("/login", loginLimiter, ...staffValidator.validateLogin, validateRequest, staffController.loginStaff);

// ===============================
// 🧪 Tests & Results
// ===============================
router.post("/collect-sample", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  sampleCollectionLimiter,  // ✅ Rate limit: 20 per minute
  ...staffValidator.validateCollectSample,
  validateRequest,
  staffController.collectSample
);

router.post("/update-sample-status", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.updateSampleStatus
);

router.post("/upload-result", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  resultUploadLimiter,  // ✅ Rate limit: 10 per minute
  ...staffValidator.validateUploadResult,
  validateRequest,
  staffController.uploadResult
);

router.get("/assigned-tests/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getAssignedTests
);

// ===============================
// ⚙️ Issues, Devices & Inventory
// ===============================
router.post("/report-issue", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.reportIssue
);

router.get("/devices/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getStaffDevices
);

router.get("/inventory/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getStaffInventory
);

// ===============================
// 🔔 Notifications
// ===============================
router.get("/notifications/:staff_id", 
  authMiddleware, 
  roleMiddleware(['Staff']), 
  staffController.getStaffNotifications
);

// ===============================
// 📊 Staff Login Activity (for Lab Owner)
router.get("/activity/:owner_id", staffController.getStaffLoginActivity);
// ===============================
// ⚙️ Inventory Stock Usage (Staff Only)
// ===============================
router.post(
  "/stock-usage",
  authMiddleware,                   // Ensure user is authenticated
  roleMiddleware(['Staff']),        // Ensure only Staff can use this route
  recordStockUsage
);

// 📦 Inventory Issue Reporting (Staff Only)
// ===============================
router.post(
  "/report-inventory-issue",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.reportInventoryIssue
);

router.post(
  "/consume-inventory",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.consumeInventory
);

router.get(
  "/inventory",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getInventoryItems
);
/**
 * @route   GET /api/staff/dashboard
 * @desc    Get staff dashboard summary (tests, notifications, devices, inventory)
 * @access  Private (Staff)
 */
router.get(
  "/dashboard",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getStaffDashboard
);

// ===============================
// 📋 Orders Management
// ===============================

/**
 * @route   GET /api/staff/orders
 * @desc    Get all orders for the lab (all statuses)
 * @access  Private (Staff)
 */
router.get(
  "/orders",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getAllLabOrders
);

/**
 * @route   GET /api/staff/pending-orders
 * @desc    Get all pending orders waiting for patient registration
 * @access  Private (Staff)
 */
router.get(
  "/pending-orders",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getPendingOrders
);

/**
 * @route   POST /api/staff/register-patient-from-order
 * @desc    Register patient and link to existing order
 * @access  Private (Staff)
 */
router.post(
  "/register-patient-from-order",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.registerPatientFromOrder
);

/**
 * @route   GET /api/staff/order-details/:order_id
 * @desc    Get all test items (OrderDetails) for a specific order
 * @access  Private (Staff)
 */
router.get(
  "/order-details/:order_id",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getOrderDetails
);

/**
 * @route   GET /api/staff/unassigned-tests
 * @desc    Get all tests that don't have staff assigned yet
 * @access  Private (Owner/Manager)
 */
router.get(
  "/unassigned-tests",
  authMiddleware,
  roleMiddleware(['Owner']),
  staffController.getUnassignedTests
);

/**
 * @route   POST /api/staff/assign-to-test
 * @desc    Manually assign or reassign staff to a specific test
 * @access  Private (Owner/Manager)
 */
router.post(
  "/assign-to-test",
  authMiddleware,
  roleMiddleware(['Owner']),
  staffController.assignStaffToTest
);

/**
 * @route   GET /api/staff/my-assigned-tests
 * @desc    Get all tests assigned to the logged-in staff member
 * @access  Private (Staff)
 */
router.get(
  "/my-assigned-tests",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getMyAssignedTests
);

/**
 * @route   PUT /api/staff/mark-completed/:detail_id
 * @desc    Mark test as completed (for fixing already uploaded results)
 * @access  Private (Staff/Owner)
 */
router.put(
  "/mark-completed/:detail_id",
  authMiddleware,
  roleMiddleware(['Staff', 'Owner']),
  staffController.markTestCompleted
);

/**
 * @route   POST /api/staff/auto-assign-tests
 * @desc    Auto-assign tests based on device-staff relationship for an order
 * @access  Private (Staff)
 */
router.post(
  "/auto-assign-tests",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.autoAssignTests
);

/**
 * @route   POST /api/staff/generate-sample-barcode/:detail_id
 * @desc    Generate barcode for a sample/test (can be called before sample collection)
 * @access  Private (Staff)
 */
router.post(
  "/generate-sample-barcode/:detail_id",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.generateSampleBarcode
);

/**
 * @route   POST /api/staff/generate-barcode/:order_id
 * @desc    Generate barcode for an order (can be called before sample collection)
 * @access  Private (Staff)
 */
router.post(
  "/generate-barcode/:order_id",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.generateBarcode
);

// ==================== FEEDBACK ROUTES ====================

/**
 * @route   POST /api/staff/feedback
 * @desc    Provide feedback on lab, test, or order
 * @access  Private (Staff)
 */
router.post(
  "/feedback",
  authMiddleware,
  roleMiddleware(['Staff']),
  ...staffValidator.validateFeedback,
  validateRequest,
  staffController.provideFeedback
);

/**
 * @route   GET /api/staff/feedback
 * @desc    Get my feedback history
 * @access  Private (Staff)
 */
router.get(
  "/feedback",
  authMiddleware,
  roleMiddleware(['Staff']),
  staffController.getMyFeedback
);

// ===============================
// ✅ Export Router
// ===============================
module.exports = router;
