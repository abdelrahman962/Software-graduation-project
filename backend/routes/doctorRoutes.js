const express = require('express');
const router = express.Router();
const doctorController = require('../controllers/doctorController');
const authMiddleware = require('../middleware/authMiddleware');

// Doctor Login
router.post('/login', doctorController.loginDoctor);

// View a patient's test history
router.get('/patients/:patient_id/history', authMiddleware(['Doctor']), doctorController.getPatientTestHistory);

// Mark a test order as urgent
router.post('/orders/:order_id/urgent', authMiddleware(['Doctor']), doctorController.markTestUrgent);

// Provide feedback on a lab, staff, or test
// router.post('/feedback', authMiddleware(['Doctor']), doctorController.provideFeedback);

// ✅ View Doctor Notifications
router.get(
  '/:doctor_id/notifications',
  authMiddleware(['Doctor']),
  doctorController.getNotifications
);
// ✅ List Patients under Care
router.get(
  '/:doctor_id/patients',
  authMiddleware(['Doctor']),
  doctorController.getPatients
);

module.exports = router;
