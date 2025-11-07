const Patient = require('../models/Patient');
const Order = require('../models/Order');
const OrderDetails = require('../models/OrderDetails');
const Result = require('../models/Result');
const Test = require('../models/Test');
const Notification = require('../models/Notification');
const Invoice = require('../models/Invoices');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// ==================== AUTHENTICATION ====================

/**
 * @desc    Patient Login
 * @route   POST /api/patient/login
 * @access  Public
 */
exports.login = async (req, res, next) => {
  try {
    const { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: '⚠️ Username and password are required' });
    }

    // Find patient by username or email
    const patient = await Patient.findOne({
      $or: [{ username }, { email: username }]
    });

    if (!patient) {
      return res.status(401).json({ message: '❌ Invalid credentials' });
    }

    // Compare password
    const isMatch = await patient.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Invalid credentials' });
    }

    // Update last login
    patient.last_login = new Date();
    await patient.save();

    // Generate JWT token
    const token = jwt.sign(
      { 
        _id: patient._id, 
        patient_id: patient.patient_id,
        role: 'patient',
        username: patient.username 
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: '✅ Login successful',
      token,
      patient: {
        _id: patient._id,
        patient_id: patient.patient_id,
        full_name: patient.full_name,
        email: patient.email,
        username: patient.username
      }
    });
  } catch (err) {
    next(err);
  }
};

// ==================== PROFILE MANAGEMENT ====================

/**
 * @desc    Get Patient Profile
 * @route   GET /api/patient/profile
 * @access  Private (Patient)
 */
exports.getProfile = async (req, res, next) => {
  try {
    const patient = await Patient.findById(req.user._id).select('-password');
    
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    res.json(patient);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Patient Profile
 * @route   PUT /api/patient/profile
 * @access  Private (Patient)
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const {
      full_name,
      phone_number,
      address,
      email,
      social_status,
      insurance_provider,
      insurance_number
    } = req.body;

    const patient = await Patient.findById(req.user._id);
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Update allowed fields
    if (full_name) patient.full_name = full_name;
    if (phone_number) patient.phone_number = phone_number;
    if (address) patient.address = address;
    if (email) patient.email = email;
    if (social_status) patient.social_status = social_status;
    if (insurance_provider) patient.insurance_provider = insurance_provider;
    if (insurance_number) patient.insurance_number = insurance_number;

    await patient.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      patient: await Patient.findById(patient._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Change Password
 * @route   PUT /api/patient/change-password
 * @access  Private (Patient)
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: '⚠️ New password must be at least 6 characters' });
    }

    const patient = await Patient.findById(req.user._id);
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Verify current password
    const isMatch = await patient.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Current password is incorrect' });
    }

    // Update password
    patient.password = newPassword;
    await patient.save();

    res.json({ message: '✅ Password changed successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== TEST ORDERS ====================

/**
 * @desc    Get All Patient Orders
 * @route   GET /api/patient/orders
 * @access  Private (Patient)
 */
exports.getMyOrders = async (req, res, next) => {
  try {
    const { status } = req.query;

    const query = { patient_id: req.user._id };
    if (status) {
      query.status = status;
    }

    const orders = await Order.find(query)
      .populate('requested_by', 'full_name employee_number')
      .populate('doctor_id', 'name')
      .populate('owner_id', 'name')
      .sort({ order_date: -1 });

    // Get order details for each order
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code price')
          .populate('staff_id', 'full_name');
        
        return {
          ...order.toObject(),
          details
        };
      })
    );

    res.json({ count: ordersWithDetails.length, orders: ordersWithDetails });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Order Details
 * @route   GET /api/patient/orders/:orderId
 * @access  Private (Patient)
 */
exports.getOrderById = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      _id: req.params.orderId,
      patient_id: req.user._id
    })
      .populate('requested_by', 'full_name employee_number')
      .populate('doctor_id', 'name')
      .populate('owner_id', 'name');

    if (!order) {
      return res.status(404).json({ message: '❌ Order not found' });
    }

    // Get order details
    const details = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price sample_type')
      .populate('staff_id', 'full_name');

    // Get invoice
    const invoice = await Invoice.findOne({ order_id: order._id });

    res.json({
      order,
      details,
      invoice
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Request New Tests (Self-Request)
 * @route   POST /api/patient/request-tests
 * @access  Private (Patient)
 */
exports.requestTests = async (req, res, next) => {
  try {
    const { owner_id, test_ids, remarks } = req.body;

    // Validate input
    if (!owner_id || !test_ids || test_ids.length === 0) {
      return res.status(400).json({ message: '⚠️ Lab and tests are required' });
    }

    // Verify tests exist and belong to the specified lab
    const tests = await Test.find({ 
      _id: { $in: test_ids },
      owner_id: owner_id 
    });

    if (tests.length !== test_ids.length) {
      return res.status(400).json({ message: '⚠️ Some tests are invalid or not available in this lab' });
    }

    // Create order
    const newOrder = new Order({
      patient_id: req.user._id,
      requested_by: null, // Self-requested
      doctor_id: null,
      order_date: new Date(),
      status: 'processing',
      remarks,
      barcode: `ORD-${Date.now()}`,
      owner_id
    });

    await newOrder.save();

    // Create order details for each test
    const orderDetails = test_ids.map(test_id => ({
      order_id: newOrder._id,
      test_id,
      status: 'pending',
      sample_collected: false
    }));

    await OrderDetails.insertMany(orderDetails);

    // Calculate invoice
    const subtotal = tests.reduce((sum, test) => sum + (test.price || 0), 0);
    const invoice = new Invoice({
      order_id: newOrder._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'pending',
      owner_id
    });

    await invoice.save();

    // Send notification to lab owner
    await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Patient',
      receiver_id: owner_id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'New Test Request',
      message: `Patient has requested ${test_ids.length} test(s). Order ID: ${newOrder.barcode}`
    });

    res.status(201).json({
      message: '✅ Test request submitted successfully',
      order: await Order.findById(newOrder._id).populate('owner_id', 'name'),
      invoice
    });
  } catch (err) {
    next(err);
  }
};

// ==================== TEST RESULTS ====================

/**
 * @desc    Get All Test Results
 * @route   GET /api/patient/results
 * @access  Private (Patient)
 */
exports.getMyResults = async (req, res, next) => {
  try {
    // Get all patient's orders
    const orders = await Order.find({ patient_id: req.user._id });
    const orderIds = orders.map(o => o._id);

    // Get completed order details
    const completedDetails = await OrderDetails.find({
      order_id: { $in: orderIds },
      status: 'completed'
    })
      .populate('order_id')
      .populate('test_id', 'test_name test_code')
      .populate('staff_id', 'full_name')
      .sort({ 'order_id.order_date': -1 });

    // Get results for these details
    const detailIds = completedDetails.map(d => d._id);
    const results = await Result.find({ detail_id: { $in: detailIds } })
      .populate('detail_id');

    // Combine details with results
    const resultsWithDetails = completedDetails.map(detail => {
      const result = results.find(r => r.detail_id._id.toString() === detail._id.toString());
      return {
        order_id: detail.order_id._id,
        order_barcode: detail.order_id.barcode,
        order_date: detail.order_id.order_date,
        test: detail.test_id,
        staff: detail.staff_id,
        result: result || null
      };
    });

    res.json({ count: resultsWithDetails.length, results: resultsWithDetails });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Result for Specific Test in Order
 * @route   GET /api/patient/results/:detailId
 * @access  Private (Patient)
 */
exports.getResultById = async (req, res, next) => {
  try {
    const detail = await OrderDetails.findById(req.params.detailId)
      .populate({
        path: 'order_id',
        match: { patient_id: req.user._id }
      })
      .populate('test_id')
      .populate('staff_id', 'full_name');

    if (!detail || !detail.order_id) {
      return res.status(404).json({ message: '❌ Result not found or access denied' });
    }

    if (detail.status !== 'completed') {
      return res.status(400).json({ message: '⚠️ Test is not yet completed' });
    }

    const result = await Result.findOne({ detail_id: detail._id });

    if (!result) {
      return res.status(404).json({ message: '❌ Result not available yet' });
    }

    res.json({
      order: detail.order_id,
      test: detail.test_id,
      staff: detail.staff_id,
      result
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Download Result (as JSON - can be extended for PDF)
 * @route   GET /api/patient/results/:detailId/download
 * @access  Private (Patient)
 */
exports.downloadResult = async (req, res, next) => {
  try {
    const detail = await OrderDetails.findById(req.params.detailId)
      .populate({
        path: 'order_id',
        match: { patient_id: req.user._id },
        populate: { path: 'owner_id', select: 'name address phone_number' }
      })
      .populate('test_id')
      .populate('staff_id', 'full_name');

    if (!detail || !detail.order_id) {
      return res.status(404).json({ message: '❌ Result not found or access denied' });
    }

    const result = await Result.findOne({ detail_id: detail._id });
    if (!result) {
      return res.status(404).json({ message: '❌ Result not available yet' });
    }

    const patient = await Patient.findById(req.user._id).select('-password');

    const report = {
      lab: detail.order_id.owner_id,
      patient: {
        name: `${patient.full_name.first} ${patient.full_name.middle || ''} ${patient.full_name.last}`,
        patient_id: patient.patient_id,
        age: patient.birthday ? Math.floor((new Date() - new Date(patient.birthday)) / 31557600000) : null,
        gender: patient.gender
      },
      order: {
        barcode: detail.order_id.barcode,
        date: detail.order_id.order_date
      },
      test: {
        name: detail.test_id.test_name,
        code: detail.test_id.test_code
      },
      result: {
        value: result.result_value,
        units: result.units,
        reference_range: result.reference_range,
        remarks: result.remarks
      },
      technician: detail.staff_id ? `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}` : null,
      report_date: new Date()
    };

    res.json(report);
  } catch (err) {
    next(err);
  }
};

// ==================== MEDICAL HISTORY ====================

/**
 * @desc    Get Medical Test History
 * @route   GET /api/patient/history
 * @access  Private (Patient)
 */
exports.getTestHistory = async (req, res, next) => {
  try {
    const { startDate, endDate, lab_id } = req.query;

    const query = { patient_id: req.user._id };

    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    if (lab_id) {
      query.owner_id = lab_id;
    }

    const orders = await Order.find(query)
      .populate('owner_id', 'name address')
      .populate('doctor_id', 'name')
      .sort({ order_date: -1 });

    // Get all details and results
    const history = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code')
          .populate('staff_id', 'full_name');

        const detailsWithResults = await Promise.all(
          details.map(async (detail) => {
            if (detail.status === 'completed') {
              const result = await Result.findOne({ detail_id: detail._id });
              return { ...detail.toObject(), result };
            }
            return detail.toObject();
          })
        );

        return {
          ...order.toObject(),
          tests: detailsWithResults
        };
      })
    );

    res.json({ count: history.length, history });
  } catch (err) {
    next(err);
  }
};

// ==================== NOTIFICATIONS ====================

/**
 * @desc    Get All Notifications
 * @route   GET /api/patient/notifications
 * @access  Private (Patient)
 */
exports.getNotifications = async (req, res, next) => {
  try {
    const { unreadOnly } = req.query;
    
    const query = {
      receiver_id: req.user._id,
      receiver_model: 'Patient'
    };

    if (unreadOnly === 'true') {
      query.is_read = false;
    }

    const notifications = await Notification.find(query)
      .sort({ created_at: -1 })
      .populate('sender_id', 'name username full_name');

    res.json({ count: notifications.length, notifications });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Mark Notification as Read
 * @route   PUT /api/patient/notifications/:notificationId/read
 * @access  Private (Patient)
 */
exports.markNotificationAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Patient'
    });

    if (!notification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    notification.is_read = true;
    await notification.save();

    res.json({ message: '✅ Notification marked as read' });
  } catch (err) {
    next(err);
  }
};

// ==================== INVOICES ====================

/**
 * @desc    Get All Invoices
 * @route   GET /api/patient/invoices
 * @access  Private (Patient)
 */
exports.getMyInvoices = async (req, res, next) => {
  try {
    const { payment_status } = req.query;

    // Get patient's orders
    const orders = await Order.find({ patient_id: req.user._id });
    const orderIds = orders.map(o => o._id);

    const query = { order_id: { $in: orderIds } };
    if (payment_status) {
      query.payment_status = payment_status;
    }

    const invoices = await Invoice.find(query)
      .populate('order_id')
      .populate('owner_id', 'name')
      .sort({ invoice_date: -1 });

    res.json({ count: invoices.length, invoices });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Invoice
 * @route   GET /api/patient/invoices/:invoiceId
 * @access  Private (Patient)
 */
exports.getInvoiceById = async (req, res, next) => {
  try {
    const invoice = await Invoice.findById(req.params.invoiceId)
      .populate({
        path: 'order_id',
        match: { patient_id: req.user._id },
        populate: { path: 'owner_id', select: 'name address phone_number' }
      });

    if (!invoice || !invoice.order_id) {
      return res.status(404).json({ message: '❌ Invoice not found or access denied' });
    }

    // Get order details
    const details = await OrderDetails.find({ order_id: invoice.order_id._id })
      .populate('test_id', 'test_name test_code price');

    res.json({
      invoice,
      tests: details
    });
  } catch (err) {
    next(err);
  }
};

// ==================== AVAILABLE LABS & TESTS ====================

/**
 * @desc    Get Available Labs
 * @route   GET /api/patient/labs
 * @access  Private (Patient)
 */
exports.getAvailableLabs = async (req, res, next) => {
  try {
    const LabOwner = require('../models/Owner');
    
    const labs = await LabOwner.find({ 
      status: 'approved',
      is_active: true 
    }).select('name address phone_number email');

    res.json({ count: labs.length, labs });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Available Tests for a Lab
 * @route   GET /api/patient/labs/:labId/tests
 * @access  Private (Patient)
 */
exports.getLabTests = async (req, res, next) => {
  try {
    const tests = await Test.find({ 
      owner_id: req.params.labId,
      is_active: true 
    }).select('test_name test_code price sample_type turnaround_time');

    res.json({ count: tests.length, tests });
  } catch (err) {
    next(err);
  }
};

// ==================== DASHBOARD ====================

/**
 * @desc    Get Patient Dashboard
 * @route   GET /api/patient/dashboard
 * @access  Private (Patient)
 */
exports.getDashboard = async (req, res, next) => {
  try {
    // Get total orders
    const totalOrders = await Order.countDocuments({ patient_id: req.user._id });
    const processingOrders = await Order.countDocuments({ patient_id: req.user._id, status: 'processing' });
    const completedOrders = await Order.countDocuments({ patient_id: req.user._id, status: 'completed' });

    // Get orders
    const orders = await Order.find({ patient_id: req.user._id });
    const orderIds = orders.map(o => o._id);

    // Get test statistics
    const allDetails = await OrderDetails.find({ order_id: { $in: orderIds } });
    const pendingTests = allDetails.filter(d => d.status === 'pending').length;
    const inProgressTests = allDetails.filter(d => d.status === 'in_progress').length;
    const completedTests = allDetails.filter(d => d.status === 'completed').length;

    // Get recent results (last 5)
    const recentCompletedDetails = await OrderDetails.find({
      order_id: { $in: orderIds },
      status: 'completed'
    })
      .populate('test_id', 'test_name')
      .populate('order_id', 'order_date barcode')
      .sort({ '-order_id.order_date': -1 })
      .limit(5);

    const recentResults = await Promise.all(
      recentCompletedDetails.map(async (detail) => {
        const result = await Result.findOne({ detail_id: detail._id });
        return {
          test_name: detail.test_id?.test_name,
          order_barcode: detail.order_id?.barcode,
          order_date: detail.order_id?.order_date,
          has_result: !!result
        };
      })
    );

    // Get invoices
    const invoices = await Invoice.find({ order_id: { $in: orderIds } });
    const pendingInvoices = invoices.filter(inv => inv.payment_status === 'pending').length;
    const paidInvoices = invoices.filter(inv => inv.payment_status === 'paid').length;
    const totalAmount = invoices.reduce((sum, inv) => sum + (inv.total_amount || 0), 0);
    const paidAmount = invoices
      .filter(inv => inv.payment_status === 'paid')
      .reduce((sum, inv) => sum + (inv.total_amount || 0), 0);

    // Get notifications
    const unreadNotifications = await Notification.countDocuments({
      receiver_id: req.user._id,
      receiver_model: 'Patient',
      is_read: false
    });

    const recentNotifications = await Notification.find({
      receiver_id: req.user._id,
      receiver_model: 'Patient'
    })
      .sort({ created_at: -1 })
      .limit(5);

    res.json({
      orders: {
        total: totalOrders,
        processing: processingOrders,
        completed: completedOrders
      },
      tests: {
        pending: pendingTests,
        inProgress: inProgressTests,
        completed: completedTests
      },
      recentResults,
      invoices: {
        pending: pendingInvoices,
        paid: paidInvoices,
        totalAmount,
        paidAmount,
        pendingAmount: totalAmount - paidAmount
      },
      notifications: {
        unread: unreadNotifications,
        recent: recentNotifications
      }
    });
  } catch (err) {
    next(err);
  }
};

module.exports = exports;