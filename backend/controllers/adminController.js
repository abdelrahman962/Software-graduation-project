const LabOwner = require('../models/Owner');
const Notification = require('../models/Notification');
const Admin = require('../models/Admin');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// =================== AUTHENTICATION ====================

/**
 * @desc    Admin Login
 * @route   POST /api/admin/login
 * @access  Public
 */
exports.login = async (req, res, next) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ message: '⚠️ Username and password are required' });
    }

    const admin = await Admin.findOne({
      $or: [{ username }, { email: username }]
    });

    if (!admin) return res.status(401).json({ message: '❌ Invalid credentials' });

    const isMatch = await admin.comparePassword(password);
    if (!isMatch) return res.status(401).json({ message: '❌ Invalid credentials' });

    const token = jwt.sign(
      { _id: admin._id, admin_id: admin.admin_id, role: 'admin', username: admin.username },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: '✅ Login successful',
      token,
      admin: {
        _id: admin._id,
        admin_id: admin.admin_id,
        username: admin.username,
        email: admin.email,
        full_name: admin.full_name
      }
    });
  } catch (err) {
    next(err);
  }
};

// ==================== LAB OWNER MANAGEMENT ====================

exports.getAllLabOwners = async (req, res, next) => {
  try {
    const owners = await LabOwner.find();
    res.json(owners);
  } catch (err) {
    next(err);
  }
};

exports.getPendingLabOwners = async (req, res, next) => {
  try {
    const pendingOwners = await LabOwner.find({ status: 'pending' });
    res.json(pendingOwners);
  } catch (err) {
    next(err);
  }
};

exports.approveLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const adminId = req.user._id; // ✅ Authenticated admin ID from token
    const { subscription_end } = req.body;

    const request = await LabOwner.findById(ownerId);
    if (!request) return res.status(404).json({ message: "❌ Lab Owner request not found" });
    if (request.status !== 'pending') return res.status(400).json({ message: "⚠️ Request is not pending" });
    if (!subscription_end) return res.status(400).json({ message: "⚠️ Subscription end date required" });

    const endDate = new Date(subscription_end);
    if (endDate <= new Date()) return res.status(400).json({ message: "⚠️ Subscription end date must be in the future" });

    // ✅ Update lab owner status and admin who approved
    request.status = 'approved';
    request.is_active = true;
    request.date_subscription = new Date();
    request.subscription_end = endDate;
    request.admin_id = adminId; // ✅ <-- Add this line

    await request.save();

    // 🟢 Send notification to the Lab Owner
    await Notification.create({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: request._id,
      receiver_model: 'Owner',
      type: 'request',
      title: 'Lab Owner Request Approved',
      message: `Congratulations! Your lab owner request has been approved. Subscription valid until ${endDate.toDateString()}.`
    });

    res.json({ message: "✅ Lab Owner approved and account activated", labOwner: request });
  } catch (err) {
    next(err);
  }
};


exports.rejectLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const adminId = req.user._id;

    const request = await LabOwner.findById(ownerId);
    if (!request) return res.status(404).json({ message: "❌ Lab Owner request not found" });
    if (request.status !== 'pending') return res.status(400).json({ message: "⚠️ Request is not pending" });

    request.status = 'rejected';
    request.is_active = false;

    await request.save();

    await Notification.create({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: request._id,
      receiver_model: 'LabOwner',
      type: 'request',
      title: 'Lab Owner Request Rejected',
      message: `Your lab owner request was rejected. Reason: ${request.rejection_reason}`
    });

    res.json({ message: "❌ Lab Owner request rejected", labOwner: request });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Lab Owner
 * @route   GET /api/admin/labowners/:ownerId
 * @access  Private (Admin)
 */
exports.getLabOwnerById = async (req, res, next) => {
  try {
    const owner = await LabOwner.findById(req.params.ownerId).select('-password');
    
    if (!owner) {
      return res.status(404).json({ message: '❌ Lab Owner not found' });
    }

    // Get additional statistics
    const Staff = require('../models/Staff');
    const Test = require('../models/Test');
    const Device = require('../models/Device');
    const Order = require('../models/Order');

    const [staffCount, testCount, deviceCount, orderCount] = await Promise.all([
      Staff.countDocuments({ owner_id: owner._id }),
      Test.countDocuments({ owner_id: owner._id }),
      Device.countDocuments({ owner_id: owner._id }),
      Order.countDocuments({ owner_id: owner._id })
    ]);

    res.json({
      owner,
      statistics: {
        totalStaff: staffCount,
        totalTests: testCount,
        totalDevices: deviceCount,
        totalOrders: orderCount
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Lab Owner Subscription
 * @route   PUT /api/admin/labowners/:ownerId/subscription
 * @access  Private (Admin)
 */
exports.updateLabOwnerSubscription = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const { subscription_end } = req.body;
    const adminId = req.user._id;

    if (!subscription_end) {
      return res.status(400).json({ message: '⚠️ Subscription end date is required' });
    }

    const endDate = new Date(subscription_end);
    if (endDate <= new Date()) {
      return res.status(400).json({ message: '⚠️ Subscription end date must be in the future' });
    }

    const owner = await LabOwner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ message: '❌ Lab Owner not found' });
    }

    const oldEndDate = owner.subscription_end;
    owner.subscription_end = endDate;
    await owner.save();

    // Send notification to owner
    await Notification.create({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: owner._id,
      receiver_model: 'Owner',
      type: 'subscription',
      title: 'Subscription Updated',
      message: `Your subscription has been extended until ${endDate.toDateString()}.`
    });

    res.json({ 
      message: '✅ Subscription updated successfully',
      labOwner: {
        _id: owner._id,
        name: owner.name,
        oldSubscriptionEnd: oldEndDate,
        newSubscriptionEnd: endDate
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Deactivate Lab Owner Account
 * @route   PUT /api/admin/labowners/:ownerId/deactivate
 * @access  Private (Admin)
 */
exports.deactivateLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const { reason } = req.body;
    const adminId = req.user._id;

    const owner = await LabOwner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ message: '❌ Lab Owner not found' });
    }

    if (!owner.is_active) {
      return res.status(400).json({ message: '⚠️ Lab Owner account is already inactive' });
    }

    owner.is_active = false;
    await owner.save();

    // Send notification to owner
    await Notification.create({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: owner._id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'Account Deactivated',
      message: `Your account has been deactivated by admin. ${reason ? 'Reason: ' + reason : ''}`
    });

    res.json({ 
      message: '✅ Lab Owner account deactivated',
      labOwner: {
        _id: owner._id,
        name: owner.name,
        is_active: false
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Reactivate Lab Owner Account
 * @route   PUT /api/admin/labowners/:ownerId/reactivate
 * @access  Private (Admin)
 */
exports.reactivateLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const adminId = req.user._id;

    const owner = await LabOwner.findById(ownerId);
    if (!owner) {
      return res.status(404).json({ message: '❌ Lab Owner not found' });
    }

    if (owner.status !== 'approved') {
      return res.status(400).json({ message: '⚠️ Lab Owner must be approved first' });
    }

    if (owner.is_active) {
      return res.status(400).json({ message: '⚠️ Lab Owner account is already active' });
    }

    // Check if subscription is still valid
    if (owner.subscription_end && new Date() > new Date(owner.subscription_end)) {
      return res.status(400).json({ 
        message: '⚠️ Cannot reactivate - subscription has expired. Please extend subscription first.' 
      });
    }

    owner.is_active = true;
    await owner.save();

    // Send notification to owner
    await Notification.create({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: owner._id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'Account Reactivated',
      message: 'Your account has been reactivated. You can now access all features.'
    });

    res.json({ 
      message: '✅ Lab Owner account reactivated',
      labOwner: {
        _id: owner._id,
        name: owner.name,
        is_active: true
      }
    });
  } catch (err) {
    next(err);
  }
};

// ==================== NOTIFICATIONS ====================
// Send a global notification to all users of a specific model
exports.sendGlobalNotification = async (req, res, next) => {
  try {
    const { type, title, message, receiver_model } = req.body;
    const adminId = req.user._id;

    // Determine recipients based on model
    let receivers = [];
    if (receiver_model === 'Owner') receivers = await LabOwner.find({}, { _id: 1 }); // lightweight: only _id
    // Add other models (Patient, Doctor, Staff) similarly if needed

    if (receivers.length === 0) {
      return res.status(400).json({ message: `⚠️ No recipients found for model ${receiver_model}` });
    }

    // Prepare notifications in bulk
    const notifications = receivers.map(receiver => ({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: receiver._id,
      receiver_model,
      type,
      title,
      message
    }));

    // Insert all notifications at once
    await Notification.insertMany(notifications);

    res.status(201).json({ message: '✅ Global notification sent', count: notifications.length });
  } catch (err) {
    next(err);
  }
};


// ==================== PAGINATED NOTIFICATIONS ====================
exports.getAllNotifications = async (req, res, next) => {
  try {
    const adminId = req.user._id;

    // Pagination parameters from query
    const page = parseInt(req.query.page) || 1;      // default page 1
    const limit = parseInt(req.query.limit) || 20;   // default 20 notifications per page
    const skip = (page - 1) * limit;

    // Fetch paginated notifications
    const notifications = await Notification.find({ receiver_id: adminId, receiver_model: 'Admin' })
      .sort({ created_at: -1 })
      .skip(skip)
      .limit(limit);

    // Total notifications count
    const total = await Notification.countDocuments({ receiver_id: adminId, receiver_model: 'Admin' });

    // Unread notifications count
    const unreadCount = await Notification.countDocuments({ receiver_id: adminId, receiver_model: 'Admin', is_read: false });

    res.json({
      total,
      page,
      totalPages: Math.ceil(total / limit),
      unreadCount,
      notifications
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Mark Notification as Read
 * @route   PUT /api/admin/notifications/:notificationId/read
 * @access  Private (Admin)
 */
exports.markNotificationAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Admin'
    });

    if (!notification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    notification.is_read = true;
    await notification.save();

    res.json({ 
      message: '✅ Notification marked as read',
      notification 
    });
  } catch (err) {
    next(err);
  }
};

// ==================== HELPERS ====================
/**
 * Fetch labs with subscriptions expiring within `days` days.
 * @param {number} days Number of days to consider for "expiring soon"
 * @param {boolean} lightweight Whether to fetch only essential fields
 * @returns {Promise<Array>} Array of lab documents
 */
const fetchExpiringLabs = async (days = 7, lightweight = false) => {
  const today = new Date();
  const soon = new Date();
  soon.setDate(today.getDate() + days);

  const projection = lightweight ? { name: 1, subscription_end: 1 } : {};

  return await LabOwner.find({ subscription_end: { $lte: soon } }, projection).sort({ subscription_end: 1 });
};

// ==================== EXPIRING / EXPIRED SUBSCRIPTIONS ====================
exports.getExpiringSubscriptions = async (req, res, next) => {
  try {
    const expiringLabs = await fetchExpiringLabs();

    if (expiringLabs.length > 0) {
      const adminId = req.user._id;

      const notifications = expiringLabs.map(lab => ({
        sender_id: null, // system
        sender_model: 'System',
        receiver_id: adminId,
        receiver_model: 'Admin',
        type: 'subscription',
        title: 'Lab Subscription Expiring',
        message: `The lab "${lab.name}" subscription will expire on ${lab.subscription_end.toDateString()}`
      }));

      await Notification.insertMany(notifications);
    }

    res.json({
      count: expiringLabs.length,
      labs: expiringLabs
    });
  } catch (err) {
    next(err);
  }
};

// ==================== DASHBOARD (Optimized with Shared Helper) ====================
exports.getDashboard = async (req, res, next) => {
  try {
    const adminId = req.user._id;

    const [totalLabs, pendingRequests, expiringLabs, unreadNotifications] = await Promise.all([
      LabOwner.countDocuments(),
      LabOwner.countDocuments({ status: 'pending' }),
      fetchExpiringLabs(7, true), // lightweight mode for dashboard
      Notification.countDocuments({ 
        receiver_id: adminId, 
        receiver_model: 'Admin', 
        is_read: false 
      })
    ]);

    res.json({
      totalLabs,
      pendingRequests,
      expiringLabsCount: expiringLabs.length,
      expiringLabs,   // lightweight: only name and subscription_end
      unreadNotifications
    });
  } catch (err) {
    next(err);
  }
};
