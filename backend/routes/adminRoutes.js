const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require('../middleware/roleMiddleware');
router.post('/login', adminController.login);

// ✅ Protect routes: only Admins
router.use(authMiddleware, roleMiddleware(['admin']));

// 🟡 Lab Owner management routes
router.get('/labowners', adminController.getAllLabOwners);
router.get('/labowners/pending', adminController.getPendingLabOwners);
router.get('/labowners/:ownerId', adminController.getLabOwnerById);
router.put('/labowner/:ownerId/approve', adminController.approveLabOwner);
router.put('/labowner/:ownerId/reject', adminController.rejectLabOwner);
router.put('/labowners/:ownerId/subscription', adminController.updateLabOwnerSubscription);
router.put('/labowners/:ownerId/deactivate', adminController.deactivateLabOwner);
router.put('/labowners/:ownerId/reactivate', adminController.reactivateLabOwner);

// 🟢 Notifications routes
router.post('/notifications/send', adminController.sendGlobalNotification);
router.get('/notifications', adminController.getAllNotifications);
router.put('/notifications/:notificationId/read', adminController.markNotificationAsRead);

// 📊 Dashboard & subscriptions
router.get('/dashboard', adminController.getDashboard);
router.get('/expiring-subscriptions', adminController.getExpiringSubscriptions);

module.exports = router;
