const LabOwner = require('../models/Owner');
const Notification = require('../models/Notification');
const Admin = require('../models/Admin');

// ==================== PROFILE MANAGEMENT ====================

/**
 * @desc    Get Admin Profile
 * @route   GET /api/admin/profile
 * @access  Private (Admin)
 */
exports.getProfile = async (req, res, next) => {
  try {
    const admin = await Admin.findById(req.user._id).select('-password');
    
    if (!admin) {
      return res.status(404).json({ message: '❌ Admin not found' });
    }

    res.json(admin);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Admin Profile
 * @route   PUT /api/admin/profile
 * @access  Private (Admin)
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const {
      name,
      email,
      phone_number
    } = req.body;

    const admin = await Admin.findById(req.user._id);
    if (!admin) {
      return res.status(404).json({ message: '❌ Admin not found' });
    }

    // Update allowed fields
    if (name) admin.name = name;
    if (email) admin.email = email;
    if (phone_number) admin.phone_number = phone_number;

    await admin.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      admin: await Admin.findById(admin._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};
const AuditLog = require('../models/AuditLog');
const Order = require('../models/Order');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');

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
    // Get approved lab owners with active subscriptions
    const owners = await LabOwner.find({
      status: 'approved',
      is_active: true,
      $or: [
        { subscription_end: null }, // No expiration date
        { subscription_end: { $gt: new Date() } } // Not expired
      ]
    });
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
    let { subscription_end, subscriptionFee } = req.body;

    const request = await LabOwner.findById(ownerId);
    if (!request) return res.status(404).json({ message: "❌ Lab Owner request not found" });
    if (request.status !== 'pending') return res.status(400).json({ message: "⚠️ Request is not pending" });

    // If subscription_end not provided, calculate from owner's chosen period
    let endDate;
    if (subscription_end) {
      endDate = new Date(subscription_end);
      if (endDate <= new Date()) return res.status(400).json({ message: "⚠️ Subscription end date must be in the future" });
    } else {
      // Use owner's chosen subscription period (default 1 month)
      const months = request.subscription_period_months || 1;
      endDate = new Date();
      endDate.setMonth(endDate.getMonth() + months);
    }

    // Generate new credentials after approval
    const generateUsername = () => {
      const first = request.name.first.toLowerCase().replace(/[^a-z0-9]/g, '');
      const last = request.name.last.toLowerCase().replace(/[^a-z0-9]/g, '');
      return `${first}${last}`;
    };

    const generatePassword = () => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
      let password = '';
      for (let i = 0; i < 10; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return password;
    };

    let newUsername = generateUsername();
    let newPassword = generatePassword();

    // Check username uniqueness across all user types
    const existingUsers = await Promise.all([
      require('../models/Patient').findOne({ username: newUsername }),
      require('../models/Doctor').findOne({ username: newUsername }),
      require('../models/Staff').findOne({ username: newUsername }),
      require('../models/Admin').findOne({ username: newUsername }),
      LabOwner.findOne({ username: newUsername, _id: { $ne: request._id } })
    ]);

    // If username exists, append a number
    let counter = 1;
    while (existingUsers.some(user => user !== null)) {
      newUsername = `${generateUsername()}${counter}`;
      const checkAgain = await Promise.all([
        require('../models/Patient').findOne({ username: newUsername }),
        require('../models/Doctor').findOne({ username: newUsername }),
        require('../models/Staff').findOne({ username: newUsername }),
        require('../models/Admin').findOne({ username: newUsername }),
        LabOwner.findOne({ username: newUsername, _id: { $ne: request._id } })
      ]);
      if (checkAgain.every(user => user === null)) break;
      counter++;
    }

    // Hash the new password
    const bcrypt = require('bcryptjs');
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    // ✅ Update lab owner with new credentials, status, admin who approved, and fee
    request.username = newUsername;
    request.password = hashedPassword;
    request.status = 'approved';
    request.is_active = true;
    request.date_subscription = new Date();
    request.subscription_end = endDate;
    request.admin_id = adminId;
    if (typeof subscriptionFee === 'number' && subscriptionFee >= 0) {
      request.subscriptionFee = subscriptionFee;
    }
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

    // Send approval email
    const sendEmail = require('../utils/sendEmail');
    const approvalSubject = '🎉 Your MedLab Account Has Been Approved!';
    const approvalBody = `
      <h2>Congratulations!</h2>
      <p>Dear ${request.name.first} ${request.name.last},</p>
      <p>Great news! Your laboratory registration for <strong>${request.lab_name}</strong> has been approved by our admin team.</p>
      
      <h3>Your Account Credentials:</h3>
      <p><strong>Username:</strong> ${newUsername}</p>
      <p><strong>Password:</strong> ${newPassword}</p>
      <p><strong>Lab Name:</strong> ${request.lab_name}</p>
      
      <h3>Subscription Information:</h3>
      <p><strong>Monthly Fee:</strong> $${request.subscriptionFee}</p>
      <p><strong>Subscription Valid Until:</strong> ${endDate.toDateString()}</p>
      
      <h3>Next Steps:</h3>
      <p>You can now log in to your account at <a href="${process.env.FRONTEND_URL || 'http://localhost:8080'}/login">MedLab System</a> using the credentials above.</p>
      <p><strong>Important:</strong> For security purposes, we strongly recommend changing your password after your first login. You can also update your username if needed in your profile settings.</p>
      
      <p>If you have any questions or need assistance getting started, please don't hesitate to contact our support team.</p>
      
      <br>
      <p>Welcome to MedLab System!<br>The MedLab Team</p>
    `;

    // TESTING: Email sending disabled
    try {
      await sendEmail(request.email, approvalSubject, approvalBody);
    } catch (emailError) {
      console.error('Failed to send approval email:', emailError);
    }
    console.log('📧 [TESTING] Approval email would be sent to:', request.email);

    res.json({ message: "✅ Lab Owner approved and account activated", labOwner: request });
  } catch (err) {
    next(err);
  }
};


exports.rejectLabOwner = async (req, res, next) => {
  try {
    const { ownerId } = req.params;
    const adminId = req.user._id;
    const { rejection_reason } = req.body;

    const request = await LabOwner.findById(ownerId);
    if (!request) return res.status(404).json({ message: "❌ Lab Owner request not found" });
    if (request.status !== 'pending') return res.status(400).json({ message: "⚠️ Request is not pending" });

    request.status = 'rejected';
    request.is_active = false;
    request.rejection_reason = rejection_reason || 'No reason provided';

    await request.save();

    await Notification.create({
      sender_id: adminId,
      sender_model: 'Admin',
      receiver_id: request._id,
      receiver_model: 'Owner',
      type: 'request',
      title: 'Lab Owner Request Rejected',
      message: `Your lab owner request was rejected. Reason: ${request.rejection_reason}`
    });

    // Send rejection email
    const sendEmail = require('../utils/sendEmail');
    const rejectionSubject = 'MedLab Registration Update';
    const rejectionBody = `
      <h2>Registration Status Update</h2>
      <p>Dear ${request.name.first} ${request.name.last},</p>
      <p>Thank you for your interest in MedLab System for <strong>${request.lab_name}</strong>.</p>
      <p>After careful review, we are unable to approve your registration at this time.</p>
      
      <h3>Reason:</h3>
      <p>${request.rejection_reason}</p>
      
      <p>If you believe this decision was made in error or would like to discuss this further, please contact our support team at <a href="mailto:${process.env.ADMIN_EMAIL || 'support@medlabsystem.com'}">${process.env.ADMIN_EMAIL || 'support@medlabsystem.com'}</a>.</p>
      
      <br>
      <p>Best regards,<br>The MedLab Team</p>
    `;

    // TESTING: Email sending disabled
    try {
      await sendEmail(request.email, rejectionSubject, rejectionBody);
    } catch (emailError) {
      console.error('Failed to send rejection email:', emailError);
    }
    console.log('📧 [TESTING] Rejection email would be sent to:', request.email);

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

    // Fetch paginated notifications with sender information
    const notifications = await Notification.find({ receiver_id: adminId, receiver_model: 'Admin' })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    // Populate sender information manually for each notification
    const populatedNotifications = await Promise.all(
      notifications.map(async (notification) => {
        if (notification.sender_id && notification.sender_model) {
          try {
            let senderModel;
            switch (notification.sender_model) {
              case 'Owner':
                senderModel = LabOwner;
                break;
              case 'Admin':
                senderModel = Admin;
                break;
              case 'Doctor':
                senderModel = require('../models/Doctor');
                break;
              case 'Patient':
                senderModel = require('../models/Patient');
                break;
              case 'Staff':
                senderModel = require('../models/Staff');
                break;
              default:
                return notification;
            }

            const sender = await senderModel.findById(notification.sender_id)
              .select('name email username full_name');
            notification.sender_id = sender;
          } catch (error) {
            console.warn('Error populating sender for notification:', notification._id, error.message);
          }
        }
        return notification;
      })
    );

    // Total notifications count
    const total = await Notification.countDocuments({ receiver_id: adminId, receiver_model: 'Admin' });

    // Unread notifications count
    const unreadCount = await Notification.countDocuments({ receiver_id: adminId, receiver_model: 'Admin', is_read: false });

    // Transform notifications to include 'from' field for frontend compatibility
    const transformedNotifications = populatedNotifications.map(notification => {
      const notificationObj = notification.toObject();

      // Add 'from' field if sender exists
      if (notification.sender_id && notification.sender_model) {
        let senderName = '';
        let senderEmail = '';

        try {
          if (notification.sender_model === 'Owner') {
            const name = notification.sender_id.name;
            senderName = name && typeof name === 'object' ? `${name.first || ''} ${name.last || ''}`.trim() : (name || '');
            senderEmail = notification.sender_id.email || '';
          } else if (notification.sender_model === 'Admin') {
            senderName = notification.sender_id.full_name || notification.sender_id.username || '';
            senderEmail = notification.sender_id.email || '';
          } else if (notification.sender_model === 'Doctor') {
            const name = notification.sender_id.name;
            senderName = name && typeof name === 'object' ? `${name.first || ''} ${name.last || ''}`.trim() : (name || '');
            senderEmail = notification.sender_id.email || '';
          } else if (notification.sender_model === 'Patient') {
            const name = notification.sender_id.name;
            senderName = name && typeof name === 'object' ? `${name.first || ''} ${name.last || ''}`.trim() : (name || '');
            senderEmail = notification.sender_id.email || '';
          } else if (notification.sender_model === 'Staff') {
            const name = notification.sender_id.name;
            senderName = name && typeof name === 'object' ? `${name.first || ''} ${name.last || ''}`.trim() : (name || '');
            senderEmail = notification.sender_id.email || '';
          }

          if (senderName || senderEmail) {
            notificationObj.from = {
              name: senderName || 'Unknown Sender',
              email: senderEmail || ''
            };
          }
        } catch (error) {
          console.warn('Error processing sender info for notification:', notification._id, error.message);
          // Continue without adding 'from' field if there's an error
        }
      }

      return notificationObj;
    });

    res.json({
      total,
      page,
      totalPages: Math.ceil(total / limit),
      unreadCount,
      notifications: transformedNotifications
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

// ==================== SYSTEM HEALTH MONITORING ====================
/**
 * @desc    Get System Health Status
 * @route   GET /api/admin/system-health
 * @access  Private (Admin)
 */
// ==================== SYSTEM HEALTH MONITORING ====================
/**
 * @desc    Get System Health Status
 * @route   GET /api/admin/system-health
 * @access  Private (Admin)
 */
exports.getSystemHealth = async (req, res, next) => {
  try {
    const startTime = Date.now();

    // Database connection health
    const dbHealth = mongoose.connection.readyState === 1 ? 'healthy' : 'unhealthy';

    // Response time calculation
    const responseTime = Date.now() - startTime;

    // Memory usage
    const memUsage = process.memoryUsage();

    // Recent errors (last 24 hours)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recentErrors = await AuditLog.countDocuments({
      level: 'error',
      timestamp: { $gte: oneDayAgo }
    });

    // Active labs count
    const activeLabs = await LabOwner.countDocuments({ is_active: true });

    res.json({
      timestamp: new Date(),
      status: dbHealth === 'healthy' && recentErrors < 10 ? 'healthy' : 'warning',
      uptime: process.uptime(),
      database: {
        status: dbHealth,
        name: mongoose.connection.name
      },
      performance: {
        responseTime: `${responseTime}ms`,
        memoryUsage: {
          rss: `${Math.round(memUsage.rss / 1024 / 1024)}MB`,
          heapUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`
        }
      },
      business: {
        activeLabs,
        recentErrors
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get all feedback from users
 * @route   GET /api/admin/feedback
 * @access  Private (Admin)
 */
exports.getAllFeedback = async (req, res, next) => {
  try {
    const Feedback = require('../models/Feedback');
    
    // Pagination
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    // Fetch feedback with user information
    const feedback = await Feedback.find()
      .populate('user_id', 'full_name email phone_number')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    // Add user_model (role) to each feedback item
    const enrichedFeedback = feedback.map(item => ({
      ...item,
      user_role: item.user_model
    }));

    const total = await Feedback.countDocuments();

    res.json({
      feedback: enrichedFeedback,
      total,
      page,
      totalPages: Math.ceil(total / limit)
    });
  } catch (err) {
    next(err);
  }
};
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

// ==================== REAL-TIME METRICS SERVICE ====================
// ==================== REAL-TIME METRICS SERVICE ====================
const metricsService = {
  cache: new Map(),
  cacheTimeout: 5 * 60 * 1000, // 5 minutes

  async getMetrics() {
    const cacheKey = 'dashboard_metrics';
    const cached = this.cache.get(cacheKey);

    if (cached && (Date.now() - cached.timestamp) < this.cacheTimeout) {
      return cached.data;
    }

    // Calculate fresh metrics
    const metrics = await this.calculateMetrics();

    // Cache the results
    this.cache.set(cacheKey, {
      timestamp: Date.now(),
      data: metrics
    });

    return metrics;
  },

  async calculateMetrics() {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const OrderDetails = require('../models/OrderDetails');

    const [todayOrders, yesterdayOrders, pendingTests, completedToday] = await Promise.all([
      // Today's orders
      Order.countDocuments({
        created_at: { $gte: today }
      }),

      // Yesterday's orders for comparison
      Order.countDocuments({
        created_at: { $gte: yesterday, $lt: today }
      }),

      // Pending tests
      OrderDetails.countDocuments({ status: { $in: ['pending', 'in_progress'] } }),

      // Completed tests today
      OrderDetails.countDocuments({
        status: 'completed',
        updated_at: { $gte: today }
      })
    ]);

    // Calculate average turnaround time (last 7 days)
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const completedTests = await OrderDetails.find({
      status: 'completed',
      updated_at: { $gte: sevenDaysAgo }
    }).populate('order_id', 'order_date');

    let avgTurnaround = 0;
    if (completedTests.length > 0) {
      const totalHours = completedTests.reduce((sum, test) => {
        const orderDate = test.order_id?.order_date;
        const completionDate = test.updated_at;
        if (orderDate && completionDate) {
          return sum + (completionDate - orderDate) / (1000 * 60 * 60);
        }
        return sum;
      }, 0);
      avgTurnaround = totalHours / completedTests.length;
    }

    return {
      todayOrders,
      orderGrowth: yesterdayOrders > 0 ? ((todayOrders - yesterdayOrders) / yesterdayOrders * 100) : 0,
      pendingTests,
      completedToday,
      avgTurnaroundHours: Math.round(avgTurnaround * 10) / 10,
      timestamp: new Date()
    };
  }
};

/**
 * @desc    Get Real-time Dashboard Metrics
 * @route   GET /api/admin/realtime-metrics
 * @access  Private (Admin)
 */
exports.getRealTimeMetrics = async (req, res, next) => {
  try {
    const metrics = await metricsService.getMetrics();
    res.json(metrics);
  } catch (err) {
    next(err);
  }
};

// ==================== ALERT SYSTEM WITH SEVERITY ====================
/*
// Commented out - Enhanced Dashboard Features
const ALERT_SEVERITY = {
  CRITICAL: { level: 1, color: 'red', icon: '🚨', autoEscalate: true, responseTime: 'immediate' },
  HIGH: { level: 2, color: 'orange', icon: '⚠️', autoEscalate: false, responseTime: 'today' },
  MEDIUM: { level: 3, color: 'yellow', icon: 'ℹ️', autoEscalate: false, responseTime: 'this week' },
  LOW: { level: 4, color: 'blue', icon: '📝', autoEscalate: false, responseTime: 'when possible' }
};

class AlertSystem {
  static async checkAndCreateAlerts(adminId) {
    const alerts = [];

    // CRITICAL: System down/unhealthy
    const systemHealth = await this.checkSystemHealth();
    if (systemHealth.status === 'critical') {
      alerts.push({
        severity: ALERT_SEVERITY.CRITICAL,
        title: 'SYSTEM CRITICAL',
        message: 'Critical system failure detected - immediate action required',
        actionRequired: 'Investigate system immediately',
        category: 'system'
      });
    }

    // HIGH: Subscriptions expiring today
    const expiringToday = await LabOwner.countDocuments({
      subscription_end: {
        $gte: new Date(new Date().setHours(0, 0, 0, 0)),
        $lt: new Date(new Date().setHours(23, 59, 59, 999))
      }
    });

    if (expiringToday > 0) {
      alerts.push({
        severity: ALERT_SEVERITY.HIGH,
        title: 'SUBSCRIPTIONS EXPIRING TODAY',
        message: `${expiringToday} lab subscription(s) expire today`,
        actionRequired: 'Contact labs immediately to prevent service disruption',
        category: 'subscription'
      });
    }

    // HIGH: High error rate
    const errorRate = await this.calculateErrorRate();
    if (errorRate > 5) {
      alerts.push({
        severity: ALERT_SEVERITY.HIGH,
        title: 'HIGH ERROR RATE DETECTED',
        message: `System error rate is ${errorRate.toFixed(1)}% - above normal threshold`,
        actionRequired: 'Monitor system performance and investigate errors',
        category: 'system'
      });
    }

    // MEDIUM: Many pending approvals
    const pendingApprovals = await LabOwner.countDocuments({ status: 'pending' });
    if (pendingApprovals > 10) {
      alerts.push({
        severity: ALERT_SEVERITY.MEDIUM,
        title: 'HIGH PENDING APPROVALS',
        message: `${pendingApprovals} lab applications awaiting approval`,
        actionRequired: 'Review and process pending applications',
        category: 'approval'
      });
    }

    // MEDIUM: Low test completion rate
    const completionRate = await this.calculateCompletionRate();
    if (completionRate < 80) {
      alerts.push({
        severity: ALERT_SEVERITY.MEDIUM,
        title: 'LOW TEST COMPLETION RATE',
        message: `Test completion rate is ${completionRate.toFixed(1)}% - below target`,
        actionRequired: 'Monitor lab performance and address bottlenecks',
        category: 'performance'
      });
    }

    // LOW: Subscriptions expiring soon (3-7 days)
    const expiringSoon = await fetchExpiringLabs(7);
    const expiringInRange = expiringSoon.filter(lab => {
      const daysUntilExpiry = Math.ceil((lab.subscription_end - new Date()) / (1000 * 60 * 60 * 24));
      return daysUntilExpiry > 1 && daysUntilExpiry <= 7;
    });

    if (expiringInRange.length > 0) {
      alerts.push({
        severity: ALERT_SEVERITY.LOW,
        title: 'SUBSCRIPTIONS EXPIRING SOON',
        message: `${expiringInRange.length} lab subscription(s) expire within 7 days`,
        actionRequired: 'Plan renewal discussions with affected labs',
        category: 'subscription'
      });
    }

    // Create notifications for new alerts
    for (const alert of alerts) {
      // Check if this alert already exists (avoid duplicates)
      const existingAlert = await Notification.findOne({
        receiver_id: adminId,
        receiver_model: 'Admin',
        type: 'alert',
        title: alert.title,
        is_read: false,
        created_at: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } // Last 24 hours
      });

      if (!existingAlert) {
        await Notification.create({
          sender_id: null,
          sender_model: 'System',
          receiver_id: adminId,
          receiver_model: 'Admin',
          type: 'alert',
          severity: alert.severity.level,
          title: alert.title,
          message: alert.message,
          action_required: alert.actionRequired,
          category: alert.category,
          is_read: false
        });
      }
    }

    return alerts;
  }

  static async checkSystemHealth() {
    try {
      // Database health
      const dbHealth = mongoose.connection.readyState === 1;

      // Memory usage check
      const memUsage = process.memoryUsage();
      const memoryHealthy = memUsage.heapUsed < 500 * 1024 * 1024; // Less than 500MB

      // Recent errors
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
      const recentErrors = await AuditLog.countDocuments({
        level: 'error',
        timestamp: { $gte: oneHourAgo }
      });

      const status = (!dbHealth || !memoryHealthy || recentErrors > 50) ? 'critical' :
                     (recentErrors > 10) ? 'warning' : 'healthy';

      return { status, dbHealth, memoryHealthy, recentErrors };
    } catch (err) {
      return { status: 'critical', error: err.message };
    }
  }

  static async calculateErrorRate() {
    try {
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const [totalLogs, errorLogs] = await Promise.all([
        AuditLog.countDocuments({ timestamp: { $gte: oneDayAgo } }),
        AuditLog.countDocuments({ level: 'error', timestamp: { $gte: oneDayAgo } })
      ]);

      return totalLogs > 0 ? (errorLogs / totalLogs) * 100 : 0;
    } catch (err) {
      return 0;
    }
  }

  static async calculateCompletionRate() {
    try {
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const [totalTests, completedTests] = await Promise.all([
        OrderDetails.countDocuments({ created_at: { $gte: sevenDaysAgo } }),
        OrderDetails.countDocuments({
          status: 'completed',
          created_at: { $gte: sevenDaysAgo }
        })
      ]);

      return totalTests > 0 ? (completedTests / totalTests) * 100 : 100;
    } catch (err) {
      return 100;
    }
  }
}
*/

/**
 * @desc    Get Active Alerts with Severity
 * @route   GET /api/admin/alerts
 * @access  Private (Admin)
 */
exports.getAlerts = async (req, res, next) => {
  try {
    const adminId = req.user._id;

    // Get existing unread system alerts/notifications
    const unreadAlerts = await Notification.find({
      receiver_id: adminId,
      receiver_model: 'Admin',
      type: { $in: ['system', 'maintenance'] },
      is_read: false
    }).sort({ createdAt: -1 });

    // Group alerts by severity (assuming we add severity to Notification model later)
    // For now, treat all as medium priority
    const alertsBySeverity = {
      critical: [], // unreadAlerts.filter(a => a.severity === 1),
      high: [], // unreadAlerts.filter(a => a.severity === 2),
      medium: unreadAlerts, // unreadAlerts.filter(a => a.severity === 3),
      low: [] // unreadAlerts.filter(a => a.severity === 4)
    };

    res.json({
      summary: {
        total: unreadAlerts.length,
        critical: alertsBySeverity.critical.length,
        high: alertsBySeverity.high.length,
        medium: alertsBySeverity.medium.length,
        low: alertsBySeverity.low.length
      },
      alerts: unreadAlerts,
      newAlertsCount: 0 // For now, no new alerts generation
    });
  } catch (err) {
    next(err);
  }
};

// ==================== EXPIRING / EXPIRED SUBSCRIPTIONS ====================
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

    const [totalLabs, pendingRequests, unreadNotifications, expiringLabs] = await Promise.all([
      LabOwner.countDocuments({ status: 'approved' }), // Only count approved labs
      LabOwner.countDocuments({ status: 'pending' }), // Count all pending requests (admins can see all)
      Notification.countDocuments({
        receiver_id: adminId,
        receiver_model: 'Admin',
        is_read: false
      }),
      fetchExpiringLabs(7, true)
    ]);

    const expiringLabsCount = expiringLabs.length;

    res.json({
      totalLabs,
      pendingRequests,
      expiringLabsCount,
      expiringLabs,
      unreadNotifications
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Admin Contact Information for Landing Page
 * @route   GET /api/admin/contact-info
 * @access  Public
 */
exports.getContactInfo = async (req, res, next) => {
  try {
    // Get the first admin (assuming there's only one main admin for contact info)
    const admin = await Admin.findOne({}, {
      full_name: 1,
      phone_number: 1,
      email: 1,
      _id: 0
    });

    if (!admin) {
      return res.status(404).json({ message: 'Admin contact information not found' });
    }

    res.json({
      success: true,
      contact: {
        name: admin.full_name ? `${admin.full_name.first} ${admin.full_name.last}`.trim() : 'Medical Lab System',
        phone: admin.phone_number || '',
        email: admin.email || ''
      }
    });
  } catch (err) {
    next(err);
  }
};
exports.getStats = async (req, res, next) => {
  try {
    const Patient = require('../models/Patient');
    const Doctor = require('../models/Doctor');
    const Staff = require('../models/Staff');
    const Order = require('../models/Order');

    // Get counts
    const thirtyDaysFromNow = new Date();
    thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);
    
    const [activeLabs, totalPatients, totalDoctors, totalStaff, totalOrders, subscriptionsEndingSoon] = await Promise.all([
      LabOwner.countDocuments({ is_active: true }),
      Patient.countDocuments(),
      Doctor.countDocuments(),
      Staff.countDocuments(),
      Order.countDocuments(),
      LabOwner.countDocuments({ 
        is_active: true, 
        subscription_end: { 
          $gte: new Date(),
          $lte: thirtyDaysFromNow
        } 
      })
    ]);

    // Calculate total revenue from active lab owners' subscription fees
    const revenueResult = await LabOwner.aggregate([
      { $match: { is_active: true } },
      { $group: { _id: null, totalRevenue: { $sum: '$subscriptionFee' } } }
    ]);
    const totalRevenue = revenueResult.length > 0 ? revenueResult[0].totalRevenue : 0;

    // Get recent activity (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const [recentLabs, recentOrders] = await Promise.all([
      LabOwner.countDocuments({ createdAt: { $gte: thirtyDaysAgo } }),
      Order.countDocuments({ createdAt: { $gte: thirtyDaysAgo } })
    ]);

    res.json({
      success: true,
      stats: {
        activeLabs,
        totalPatients,
        totalDoctors,
        totalStaff,
        totalOrders,
        subscriptionsEndingSoon,
        totalRevenue: totalRevenue.toFixed(2),
        recentActivity: {
          newLabsLast30Days: recentLabs,
          ordersLast30Days: recentOrders
        }
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Reply to Owner Notification (with WhatsApp)
 * @route   POST /api/admin/notifications/:notificationId/reply
 * @access  Private (Admin)
 */
exports.replyToOwnerNotification = async (req, res, next) => {
  try {
    const { notificationId } = req.params;
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({ message: '⚠️ Reply message is required' });
    }

    // Get the original notification
    const originalNotification = await Notification.findOne({
      _id: notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Admin'
    });

    if (!originalNotification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    // Get the owner who sent the original message
    const owner = await LabOwner.findById(originalNotification.sender_id);
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Send WhatsApp reply to owner
    const whatsappMessage = `📬 Reply from Admin\n\n💬 ${message}\n\n---\nRegards,\nMedical Lab System Admin`;

    const { sendWhatsAppMessage } = require('../utils/sendWhatsApp');
    const whatsappSuccess = await sendWhatsAppMessage(
      owner.phone_number,
      whatsappMessage,
      [],
      false, // Don't fallback to email
      '',
      ''
    );

    // Determine conversation_id
    const conversationId = originalNotification.conversation_id || originalNotification._id;

    // Create reply notification in database
    const replyNotification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Admin',
      receiver_id: owner._id,
      receiver_model: 'Owner',
      type: 'message',
      title: `Re: ${originalNotification.title}`,
      message,
      parent_id: notificationId,
      conversation_id: conversationId,
      is_reply: true
    });

    // Update original notification's conversation_id if it doesn't have one
    if (!originalNotification.conversation_id) {
      originalNotification.conversation_id = originalNotification._id;
      await originalNotification.save();
    }

    // Mark original notification as read
    originalNotification.is_read = true;
    await originalNotification.save();

    res.status(201).json({
      message: whatsappSuccess
        ? '✅ Reply sent successfully via WhatsApp and notification'
        : '✅ Reply notification created (WhatsApp failed)',
      notification: replyNotification,
      whatsappSent: whatsappSuccess
    });

  } catch (err) {
    console.error('Reply error:', err);
    next(err);
  }
};

// ==================== ADMIN REPORTS ====================

/**
 * @desc    Generate comprehensive admin reports
 * @route   GET /api/admin/reports
 * @access  Private (Admin)
 */
exports.generateReports = async (req, res, next) => {
  try {
    const { type = 'comprehensive', period = 'monthly', startDate, endDate } = req.query;

    // Calculate date range based on period
    let dateFilter = {};
    const now = new Date();

    if (period === 'custom' && startDate && endDate) {
      dateFilter = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    } else {
      const periodMap = {
        'daily': 1,
        'weekly': 7,
        'monthly': 30,
        'yearly': 365
      };

      const days = periodMap[period] || 30;
      dateFilter = {
        $gte: new Date(now.getTime() - (days * 24 * 60 * 60 * 1000))
      };
    }

    const reportData = {};

    // Basic platform statistics
    const [
      totalLabs,
      activeLabs,
      pendingLabs,
      totalRevenue,
      monthlyRevenue,
      newRegistrations,
      totalPatients,
      totalTests,
      totalOrders
    ] = await Promise.all([
      LabOwner.countDocuments(),
      LabOwner.countDocuments({ status: 'approved', is_active: true }),
      LabOwner.countDocuments({ status: 'pending' }),
      // Total revenue: sum of subscription fees for all approved labs
      LabOwner.aggregate([
        { $match: { status: 'approved' } },
        { $group: { _id: null, total: { $sum: '$subscriptionFee' } } }
      ]),
      // Monthly revenue: labs that started subscription in the period
      LabOwner.aggregate([
        { $match: { status: 'approved', date_subscription: dateFilter } },
        { $group: { _id: null, total: { $sum: '$subscriptionFee' } } }
      ]),
      // New registrations in the period
      LabOwner.countDocuments({ createdAt: dateFilter }),
      require('../models/Patient').countDocuments(),
      require('../models/Test').countDocuments(),
      require('../models/Order').countDocuments()
    ]);

    // Calculate more accurate revenue metrics
    const totalRevenueAmount = totalRevenue[0]?.total || 0;
    const monthlyRevenueAmount = monthlyRevenue[0]?.total || 0;

    // Base report data
    reportData.platform = {
      totalLabs: totalLabs || 0,
      activeLabs: activeLabs || 0,
      pendingLabs: pendingLabs || 0,
      totalRevenue: totalRevenueAmount,
      monthlyRevenue: monthlyRevenueAmount,
      newRegistrations: newRegistrations || 0,
      totalPatients: totalPatients || 0,
      totalTests: totalTests || 0,
      totalOrders: totalOrders || 0,
      period,
      generatedAt: new Date()
    };

    // Generate specific report types
    switch (type) {
      case 'comprehensive':
        // Add comprehensive data
        const labStatuses = await LabOwner.aggregate([
          { $group: { _id: '$status', count: { $sum: 1 } } }
        ]);

        const subscriptionDistribution = await LabOwner.aggregate([
          { $match: { status: 'approved' } },
          { $group: { _id: '$subscriptionFee', count: { $sum: 1 } } }
        ]);

        const recentActivity = await LabOwner.find({
          createdAt: dateFilter
        })
        .select('lab_name name.first name.last email status createdAt')
        .sort({ createdAt: -1 })
        .limit(10);

        // Include all individual report data for comprehensive view
        const compRevenueByMonth = await LabOwner.aggregate([
          { $match: { status: 'approved', date_subscription: { $exists: true } } },
          {
            $group: {
              _id: {
                year: { $year: '$date_subscription' },
                month: { $month: '$date_subscription' }
              },
              revenue: { $sum: '$subscriptionFee' },
              count: { $sum: 1 }
            }
          },
          { $sort: { '_id.year': -1, '_id.month': -1 } },
          { $limit: 12 }
        ]);

        const compProjectedRevenue = await LabOwner.aggregate([
          { $match: { status: 'approved', subscription_end: { $gt: new Date() } } },
          {
            $group: {
              _id: {
                year: { $year: '$subscription_end' },
                month: { $month: '$subscription_end' }
              },
              expiringRevenue: { $sum: '$subscriptionFee' }
            }
          }
        ]);

        const compLabsByStatus = await LabOwner.aggregate([
          {
            $group: {
              _id: '$status',
              count: { $sum: 1 },
              labs: {
                $push: {
                  lab_name: '$lab_name',
                  email: '$email',
                  subscriptionFee: '$subscriptionFee',
                  createdAt: '$createdAt',
                  subscription_end: '$subscription_end'
                }
              }
            }
          }
        ]);

        const compExpiringLabs = await LabOwner.find({
          status: 'approved',
          subscription_end: { $lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) }
        })
        .select('lab_name email subscription_end subscriptionFee')
        .sort({ subscription_end: 1 });

        const compSubscriptionMetrics = await LabOwner.aggregate([
          { $match: { status: 'approved' } },
          {
            $group: {
              _id: null,
              totalRevenue: { $sum: '$subscriptionFee' },
              averageFee: { $avg: '$subscriptionFee' },
              minFee: { $min: '$subscriptionFee' },
              maxFee: { $max: '$subscriptionFee' }
            }
          }
        ]);

        const compRenewalsNeeded = await LabOwner.countDocuments({
          status: 'approved',
          subscription_end: { $lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) }
        });

        const compSubscriptionTrends = await LabOwner.aggregate([
          { $match: { status: 'approved', date_subscription: { $exists: true } } },
          {
            $group: {
              _id: {
                year: { $year: '$date_subscription' },
                month: { $month: '$date_subscription' }
              },
              newSubscriptions: { $sum: 1 },
              revenue: { $sum: '$subscriptionFee' }
            }
          },
          { $sort: { '_id.year': -1, '_id.month': -1 } },
          { $limit: 12 }
        ]);

        reportData.comprehensive = {
          labStatuses,
          subscriptionDistribution,
          recentActivity,
          growthMetrics: {
            // Lab growth: percentage of active labs out of total approved labs
            labGrowth: totalLabs > 0 ? ((activeLabs / totalLabs) * 100).toFixed(1) : 0,
            // Revenue growth: compare monthly to total (simplified - ideally compare month-over-month)
            revenueGrowth: totalRevenueAmount > 0 ? ((monthlyRevenueAmount / totalRevenueAmount) * 100).toFixed(1) : 0,
            // New registrations this period
            newLabsThisPeriod: newRegistrations
          }
        };

        // Include individual report sections for comprehensive view
        reportData.revenue = {
          monthlyRevenue: compRevenueByMonth,
          projectedRevenue: compProjectedRevenue,
          averageRevenuePerLab: activeLabs > 0 ? (totalRevenueAmount / activeLabs).toFixed(2) : 0,
          // Revenue growth: compare most recent month to previous month
          revenueGrowth: compRevenueByMonth.length > 1 ?
            compRevenueByMonth[1]?.revenue > 0 ?
              (((compRevenueByMonth[0]?.revenue || 0) - (compRevenueByMonth[1]?.revenue || 0)) / compRevenueByMonth[1].revenue * 100).toFixed(1) : 0 : 0,
          totalRevenue: totalRevenueAmount,
          monthlyRevenueTotal: monthlyRevenueAmount
        };

        reportData.labs = {
          totalLabs: totalLabs || 0,
          labsByStatus: compLabsByStatus,
          expiringLabs: compExpiringLabs,
          activeLabs: activeLabs || 0,
          inactiveLabs: await LabOwner.countDocuments({ is_active: false }),
          subscriptionDistribution: await LabOwner.aggregate([
            { $match: { status: 'approved' } },
            { $group: { _id: '$subscriptionFee', count: { $sum: 1 } } }
          ])
        };

        reportData.subscriptions = {
          totalSubscriptions: activeLabs || 0,
          activeSubscriptions: activeLabs || 0,
          expiredSubscriptions: await LabOwner.countDocuments({
            status: 'approved',
            subscription_end: { $lt: new Date() }
          }),
          subscriptionsByStatus: await LabOwner.aggregate([
            { $group: { _id: '$status', count: { $sum: 1 } } }
          ]),
          subscriptionsByTier: await LabOwner.aggregate([
            { $match: { status: 'approved' } },
            { $group: { _id: '$subscriptionFee', count: { $sum: 1 } } }
          ]),
          revenueBySubscriptionTier: await LabOwner.aggregate([
            { $match: { status: 'approved' } },
            { $group: { _id: '$subscriptionFee', totalRevenue: { $sum: '$subscriptionFee' }, count: { $sum: 1 } } }
          ]),
          metrics: compSubscriptionMetrics[0] || {},
          renewalsNeeded: compRenewalsNeeded,
          subscriptionTrends: compSubscriptionTrends,
          churnRate: '0.0', // Would need historical data to calculate
          lifetimeValue: compSubscriptionMetrics[0]?.averageFee ? (compSubscriptionMetrics[0].averageFee * 12).toFixed(2) : 0,
          totalRevenue: totalRevenueAmount
        };
        break;

      case 'revenue':
        const revenueByMonth = await LabOwner.aggregate([
          { $match: { status: 'approved', date_subscription: { $exists: true } } },
          {
            $group: {
              _id: {
                year: { $year: '$date_subscription' },
                month: { $month: '$date_subscription' }
              },
              revenue: { $sum: '$subscriptionFee' },
              count: { $sum: 1 }
            }
          },
          { $sort: { '_id.year': -1, '_id.month': -1 } },
          { $limit: 12 }
        ]);

        const projectedRevenue = await LabOwner.aggregate([
          { $match: { status: 'approved', subscription_end: { $gt: new Date() } } },
          {
            $group: {
              _id: {
                year: { $year: '$subscription_end' },
                month: { $month: '$subscription_end' }
              },
              expiringRevenue: { $sum: '$subscriptionFee' }
            }
          }
        ]);

        reportData.revenue = {
          monthlyRevenue: revenueByMonth,
          projectedRevenue,
          averageRevenuePerLab: activeLabs > 0 ? (totalRevenueAmount / activeLabs).toFixed(2) : 0,
          // Revenue growth: compare most recent month to previous month
          revenueGrowth: revenueByMonth.length > 1 ?
            revenueByMonth[1]?.revenue > 0 ?
              (((revenueByMonth[0]?.revenue || 0) - (revenueByMonth[1]?.revenue || 0)) / revenueByMonth[1].revenue * 100).toFixed(1) : 0 : 0,
          totalRevenue: totalRevenueAmount,
          monthlyRevenueTotal: monthlyRevenueAmount
        };
        break;

      case 'labs':
        const labsByStatus = await LabOwner.aggregate([
          {
            $group: {
              _id: '$status',
              count: { $sum: 1 },
              labs: {
                $push: {
                  lab_name: '$lab_name',
                  email: '$email',
                  subscriptionFee: '$subscriptionFee',
                  createdAt: '$createdAt',
                  subscription_end: '$subscription_end'
                }
              }
            }
          }
        ]);

        const expiringLabs = await LabOwner.find({
          status: 'approved',
          subscription_end: { $lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) }
        })
        .select('lab_name email subscription_end subscriptionFee')
        .sort({ subscription_end: 1 });

        reportData.labs = {
          totalLabs: totalLabs || 0,
          labsByStatus,
          expiringLabs,
          activeLabs: activeLabs || 0,
          inactiveLabs: await LabOwner.countDocuments({ is_active: false }),
          subscriptionDistribution: await LabOwner.aggregate([
            { $match: { status: 'approved' } },
            { $group: { _id: '$subscriptionFee', count: { $sum: 1 } } }
          ])
        };
        break;

      case 'subscriptions':
        const subscriptionMetrics = await LabOwner.aggregate([
          { $match: { status: 'approved' } },
          {
            $group: {
              _id: null,
              totalRevenue: { $sum: '$subscriptionFee' },
              averageFee: { $avg: '$subscriptionFee' },
              minFee: { $min: '$subscriptionFee' },
              maxFee: { $max: '$subscriptionFee' }
            }
          }
        ]);

        const renewalsNeeded = await LabOwner.countDocuments({
          status: 'approved',
          subscription_end: { $lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) }
        });

        const subscriptionTrends = await LabOwner.aggregate([
          { $match: { status: 'approved', date_subscription: { $exists: true } } },
          {
            $group: {
              _id: {
                year: { $year: '$date_subscription' },
                month: { $month: '$date_subscription' }
              },
              newSubscriptions: { $sum: 1 },
              revenue: { $sum: '$subscriptionFee' }
            }
          },
          { $sort: { '_id.year': -1, '_id.month': -1 } },
          { $limit: 12 }
        ]);

        reportData.subscriptions = {
          totalSubscriptions: activeLabs || 0,
          activeSubscriptions: activeLabs || 0,
          expiredSubscriptions: await LabOwner.countDocuments({
            status: 'approved',
            subscription_end: { $lt: new Date() }
          }),
          subscriptionsByStatus: await LabOwner.aggregate([
            { $group: { _id: '$status', count: { $sum: 1 } } }
          ]),
          subscriptionsByTier: await LabOwner.aggregate([
            { $match: { status: 'approved' } },
            { $group: { _id: '$subscriptionFee', count: { $sum: 1 } } }
          ]),
          revenueBySubscriptionTier: await LabOwner.aggregate([
            { $match: { status: 'approved' } },
            { $group: { _id: '$subscriptionFee', totalRevenue: { $sum: '$subscriptionFee' }, count: { $sum: 1 } } }
          ]),
          metrics: subscriptionMetrics[0] || {},
          renewalsNeeded,
          subscriptionTrends,
          churnRate: '0.0', // Would need historical data to calculate
          lifetimeValue: subscriptionMetrics[0]?.averageFee ? (subscriptionMetrics[0].averageFee * 12).toFixed(2) : 0,
          totalRevenue: totalRevenueAmount
        };
        break;
    }

    res.json({
      success: true,
      report: {
        type,
        period,
        dateRange: dateFilter,
        data: reportData
      }
    });

  } catch (err) {
    console.error('Report generation error:', err);
    next(err);
  }
};

module.exports = exports;


