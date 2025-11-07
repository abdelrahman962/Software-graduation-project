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

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: '⚠️ Username and password are required' });
    }

    // Find admin by username or email
    const admin = await Admin.findOne({
      $or: [{ username }, { email: username }]
    });

    if (!admin) {
      return res.status(401).json({ message: '❌ Invalid credentials' });
    }

    // Compare password
    const isMatch = await admin.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Invalid credentials' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        _id: admin._id, 
        admin_id: admin.admin_id,
        role: 'admin',
        username: admin.username
      },
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

// 🟡 Get all Lab Owners
exports.getAllLabOwners = async (req, res, next) => {
  try {
    const owners = await LabOwner.find();
    res.json(owners);
  } catch (err) {
    next(err);
  }
};

// ♻️ Renew subscription manually (e.g. +12 months)
exports.renewSubscription = async (req, res, next) => {
  try {
    const { ownerId, durationMonths } = req.body;
    const labOwner = await LabOwner.findById(ownerId);

    if (!labOwner) return res.status(404).json({ message: "❌ Lab Owner not found" });

    const newEndDate = new Date(labOwner.subscription_end);
    newEndDate.setMonth(newEndDate.getMonth() + (durationMonths || 12));

    labOwner.subscription_end = newEndDate;
    labOwner.is_active = true;
    await labOwner.save();

    res.json({ message: "🔁 Subscription renewed", newEndDate });
  } catch (err) {
    next(err);
  }
};

// 🟡 Get all pending Lab Owner requests
exports.getPendingLabOwners = async (req, res, next) => {
  try {
    const pendingOwners = await LabOwner.find({ status: 'pending' });
    res.json(pendingOwners);
  } catch (err) {
    next(err);
  }
};

// 🟢 Approve a Lab Owner request
exports.approveLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const adminId = req.user._id; // assuming authMiddleware sets req.user
    const { subscription_end } = req.body;

    const request = await LabOwner.findById(ownerId);
    if (!request) return res.status(404).json({ message: "❌ Lab Owner request not found" });
    if (request.status !== 'pending') return res.status(400).json({ message: "⚠️ Request is not pending" });
    if (!subscription_end) return res.status(400).json({ message: "⚠️ Subscription end date required" });

    const endDate = new Date(subscription_end);
    if (endDate <= new Date()) return res.status(400).json({ message: "⚠️ Subscription end date must be in the future" });

    // Approve and activate
    request.status = 'approved';
    request.is_active = true;
    request.date_subscription = new Date();
    request.subscription_end = endDate;

    await request.save();

    // Notify Lab Owner
    await Notification.create({
      sender_id: adminId,          // admin is the sender
      sender_model: 'Admin',            // sender type
      receiver_id: request._id,
      receiver_model: 'LabOwner',
      type: 'request',
      title: 'Lab Owner Request Approved',
      message: `Congratulations! Your lab owner request has been approved. Subscription valid until ${endDate.toDateString()}.`
    });

    res.json({ message: "✅ Lab Owner approved and account created", labOwner: request });

  } catch (err) {
    next(err);
  }
};

// 🔴 Reject a Lab Owner request
exports.rejectLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
const adminId = req.user._id; // assuming authMiddleware sets req.user
    const request = await LabOwner.findById(ownerId);
    if (!request) return res.status(404).json({ message: "❌ Lab Owner request not found" });
    if (request.status !== 'pending') return res.status(400).json({ message: "⚠️ Request is not pending" });

    request.status = 'rejected';
    request.is_active = false;

    await request.save();

    // Notify Lab Owner
    await Notification.create({
      sender_id: adminId,          // admin is the sender
      sender_model: 'Admin',            // sender type
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

// 🟢 Send global notification
exports.sendGlobalNotification = async (req, res, next) => {
  try {
    const { type, title, message, receiver_model } = req.body;
    const adminId = req.user._id; // assuming authMiddleware sets req.user

    // Fetch all receivers based on model type
    let receivers = [];
    if (receiver_model === 'LabOwner') {
      receivers = await LabOwner.find({}); // All lab owners
    }
    // Add other models if needed (Patient, Doctor)

    const notifications = receivers.map(receiver => ({
      sender_id: adminId,               // admin is the sender
      sender_model: 'Admin',            // sender type
      receiver_id: receiver._id,
      receiver_model,
      type,
      title,
      message
    }));

    await Notification.insertMany(notifications);

    res.status(201).json({ message: '✅ Global notification sent', count: notifications.length });
  } catch (err) {
    next(err);
  }
};


// 🟡 Get all notifications sent (history)
exports.getAllNotifications = async (req, res, next) => {
  try {
    const notifications = await Notification.find().sort({ created_at: -1 });
    res.json(notifications);
  } catch (err) {
    next(err);
  }
};
