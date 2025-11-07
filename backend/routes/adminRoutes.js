const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');

// ✅ Protect routes: only Admins
router.use(authMiddleware, roleMiddleware(['admin']));

// 🟡 Lab Owner management routes
router.get('/labowners', adminController.getAllLabOwners);
router.get('/labowners/pending', adminController.getPendingLabOwners);
router.put('/labowner/:ownerId/approve', adminController.approveLabOwner);
router.put('/labowner/:ownerId/reject', adminController.rejectLabOwner);
router.post('/subscriptions/renew', adminController.renewSubscription);

// 🟢 Notifications routes
router.post('/notifications/send', adminController.sendGlobalNotification);
router.get('/notifications', adminController.getAllNotifications);

module.exports = router;
