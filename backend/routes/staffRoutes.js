const express = require("express");
const router = express.Router();
const staffController = require("../controllers/staffController");
const { loginLimiter } = require('../middleware/rateLimitMiddleware');

// ===============================
// 🧩 Authentication & Patient
// ===============================
router.post("/login", loginLimiter, staffController.loginStaff);
router.post("/register-patient", staffController.registerPatient);

// ===============================
// 🧪 Tests & Results
// ===============================
router.post("/upload-result", staffController.uploadResult);
router.post("/update-sample-status", staffController.updateSampleStatus);
router.get("/assigned-tests/:staff_id", staffController.getAssignedTests);

// ===============================
// ⚙️ Issues, Devices & Inventory
// ===============================
router.post("/report-issue", staffController.reportIssue);
router.get("/devices/:staff_id", staffController.getStaffDevices);
router.get("/inventory/:staff_id", staffController.getStaffInventory);

// ===============================
// 🔔 Notifications
// ===============================
router.get("/notifications/:staff_id", staffController.getStaffNotifications);

// ===============================
// 📊 Staff Login Activity (for Lab Owner)
router.get("/activity/:owner_id", staffController.getStaffLoginActivity);

// ===============================
// ✅ Export Router
// ===============================
module.exports = router;
