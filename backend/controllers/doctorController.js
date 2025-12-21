const mongoose = require('mongoose');
const Doctor = require('../models/Doctor');
const Patient = require('../models/Patient');
const Order = require('../models/Order');
const Test = require('../models/Test');
const OrderDetails = require('../models/OrderDetails');
const Invoice = require('../models/Invoices');
const Result = require('../models/Result');
const Notification = require('../models/Notification');
const LabOwner = require('../models/Owner');
const Feedback = require('../models/Feedback');
const jwt = require('jsonwebtoken');
const sendEmail = require('../utils/sendEmail');
const sendSMS = require('../utils/sendSMS');
const { sendWhatsAppMessage } = require('../utils/sendWhatsApp');

// ✅ Doctor Login
exports.loginDoctor = async (req, res) => {
  try {
    const { username, password } = req.body;
    const doctor = await Doctor.findOne({ username });
    if (!doctor || !(await doctor.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = jwt.sign({ id: doctor._id, role: 'Doctor' }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ message: 'Login successful', token, doctor });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Get Doctor Profile
exports.getProfile = async (req, res, next) => {
  try {
    const doctor = await Doctor.findById(req.user._id).select('-password');
    
    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    res.json(doctor);
  } catch (err) {
    next(err);
  }
};

// ✅ Update Doctor Profile
exports.updateProfile = async (req, res, next) => {
  try {
    const {
      name,
      phone_number,
      email,
      identity_number,
      birthday,
      gender
    } = req.body;

    const doctor = await Doctor.findById(req.user._id);
    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    // Update allowed fields
    if (name) doctor.name = name;
    if (phone_number) doctor.phone_number = phone_number;
    if (email) doctor.email = email;
    if (identity_number) doctor.identity_number = identity_number;
    if (birthday) doctor.birthday = birthday;
    if (gender) doctor.gender = gender;

    await doctor.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      doctor: await Doctor.findById(doctor._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

// ✅ Change Doctor Password
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // Validate input
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: '⚠️ New password must be at least 6 characters long' });
    }

    // Find doctor
    const doctor = await Doctor.findById(req.user.id);
    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    // Verify current password
    const isMatch = await doctor.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Current password is incorrect' });
    }

    // Update password
    doctor.password = newPassword;
    await doctor.save();

    res.json({ message: '✅ Password changed successfully' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Request Test for Patient
exports.requestTestForPatient = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  
  try {
    const { patient_id, owner_id, test_ids, remarks, is_urgent } = req.body;
    const doctor_id = req.user.id;

    // Validate input
    if (!patient_id || !owner_id || !test_ids || test_ids.length === 0) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ 
        message: '⚠️ Patient, lab, and tests are required' 
      });
    }

    // Verify patient exists
    const patient = await Patient.findById(patient_id).session(session);
    if (!patient) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Verify lab exists and is active
    const lab = await LabOwner.findById(owner_id).session(session);
    if (!lab || !lab.is_active || lab.status !== 'approved') {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ 
        message: '⚠️ Selected lab is not available' 
      });
    }

    // Verify tests exist and belong to this lab
    const tests = await Test.find({ 
      _id: { $in: test_ids },
      owner_id: owner_id,
      is_active: true 
    }).session(session);

    if (tests.length !== test_ids.length) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ 
        message: '⚠️ Some tests are invalid or not available in this lab' 
      });
    }

    // Create order (within transaction)
    const newOrder = await Order.create([{
      patient_id: patient._id,
      requested_by: doctor_id,
      requested_by_model: 'Doctor',
      doctor_id: doctor_id,
      order_date: new Date(),
      status: 'processing',
      remarks: is_urgent ? 'urgent' : remarks,
      owner_id,
      is_patient_registered: true
    }], { session });

    // Create order details for each test
    const orderDetails = test_ids.map(test_id => ({
      order_id: newOrder[0]._id,
      test_id,
      status: is_urgent ? 'urgent' : 'pending',
      sample_collected: false
    }));

    await OrderDetails.insertMany(orderDetails, { session });

    // Calculate invoice
    const subtotal = tests.reduce((sum, test) => sum + (test.price || 0), 0);
    const invoice = await Invoice.create([{
      invoice_id: `INV-${String(Date.now()).slice(-6)}`, // Simple ID for doctor orders
      order_id: newOrder[0]._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'paid', // Mark as paid initially
      payment_method: 'cash', // Default payment method
      payment_date: new Date(),
      paid_by: doctor_id,
      owner_id,
      items: tests.map(t => ({
        test_id: t._id,
        test_name: t.test_name,
        price: t.price,
        quantity: 1
      }))
    }], { session });

    // Send invoice notification to patient
    await Notification.create([{
      sender_id: doctor_id,
      sender_model: 'Doctor',
      receiver_id: patient._id,
      receiver_model: 'Patient',
      type: 'payment',
      title: 'Invoice Generated',
      message: `Your invoice for tests ordered by Dr. ${req.user.username || 'your doctor'} has been generated. Total: ${subtotal} ILS. Payment status: Paid.`
    }], { session });

    // Send notification to patient
    await Notification.create([{
      sender_id: doctor_id,
      sender_model: 'Doctor',
      receiver_id: patient._id,
      receiver_model: 'Patient',
      type: 'test_result',
      title: 'Test Ordered by Doctor',
      message: `Dr. ${req.user.username || 'Your doctor'} has ordered ${test_ids.length} test(s) for you.${is_urgent ? ' (URGENT)' : ''} Please visit ${lab.lab_name} for sample collection.`
    }], { session });

    // Send notification to lab owner
    await Notification.create([{
      sender_id: doctor_id,
      sender_model: 'Doctor',
      receiver_id: owner_id,
      receiver_model: 'Owner',
      type: 'request',
      title: is_urgent ? 'Urgent Test Request from Doctor' : 'New Test Request from Doctor',
      message: `Doctor has requested ${test_ids.length} test(s) for patient ${patient.full_name.first} ${patient.full_name.last}.${is_urgent ? ' - URGENT PROCESSING REQUIRED' : ''}`
    }], { session });

    // If urgent, notify all staff at the lab
    if (is_urgent) {
      const Staff = require('../models/Staff');
      const labStaff = await Staff.find({ owner_id }).session(session);
      
      const staffNotifications = labStaff.map(staff => ({
        sender_id: doctor_id,
        sender_model: 'Doctor',
        receiver_id: staff._id,
        receiver_model: 'Staff',
        type: 'request',
        title: '🚨 URGENT Test Request',
        message: `Urgent test order from doctor for patient ${patient.full_name.first} ${patient.full_name.last}.`
      }));

      await Notification.insertMany(staffNotifications, { session });
    }

    // Commit transaction
    await session.commitTransaction();

    // Send email and SMS to patient after transaction commits
    const emailSubject = `Test Order from Dr. ${req.user.username || 'Your Doctor'}`;
    const emailMessage = `
Hello ${patient.full_name.first},

Dr. ${req.user.username || 'Your doctor'} has ordered ${test_ids.length} test(s) for you${is_urgent ? ' (URGENT)' : ''}.

Lab: ${lab.lab_name}
Tests: ${tests.map(t => t.test_name).join(', ')}
Total Cost: ${subtotal} ILS

Next Steps:
1. Visit ${lab.lab_name} at your earliest convenience
2. Bring your ID for verification
3. Sample will be collected and processed
4. Results will be available in your account

${is_urgent ? '⚠️ This is an URGENT test request. Please visit the lab immediately.' : ''}

Lab Contact: ${lab.phone_number}

Best regards,
MedLab System
    `;

    // Send WhatsApp notification to patient (with email fallback)
    const whatsappMessage = `Hello ${patient.full_name.first},\n\nDr. ${req.user.username || 'Your doctor'} has ordered ${test_ids.length} test(s) for you${is_urgent ? ' (URGENT)' : ''}.\n\nLab: ${lab.lab_name}\nTests: ${tests.map(t => t.test_name).join(', ')}\nTotal Cost: ${subtotal} ILS\n\nNext Steps:\n1. Visit ${lab.lab_name} at your earliest convenience\n2. Bring your ID for verification\n3. Sample will be collected and processed\n4. Results will be available in your account\n\n${is_urgent ? '⚠️ This is an URGENT test request. Please visit the lab immediately.' : ''}\n\nLab Contact: ${lab.phone_number}\n\nBest regards,\nMedLab System`;

    const whatsappSuccess = await sendWhatsAppMessage(
      patient.phone_number,
      whatsappMessage,
      [],
      true, // fallback to email
      emailSubject,
      emailMessage
    );

    if (!whatsappSuccess) {
      // Fallback to SMS if both WhatsApp and email fail
      await sendSMS(patient.phone_number, `Dr. ${req.user.username} ordered ${test_ids.length} test(s) for you${is_urgent ? ' (URGENT)' : ''}. Visit ${lab.lab_name} for sample collection. Tests: ${tests.map(t => t.test_name).join(', ')}`);
    }

    res.status(201).json({
      success: true,
      message: `✅ Test request submitted successfully${is_urgent ? ' as URGENT' : ''}. Patient notified via email and SMS.`,
      order: {
        _id: newOrder[0]._id,
        status: newOrder[0].status,
        is_urgent,
        patient: {
          name: `${patient.full_name.first} ${patient.full_name.last}`,
          patient_id: patient.patient_id
        },
        lab: {
          name: `${lab.name.first} ${lab.name.last}`
        },
        tests: tests.map(t => ({
          name: t.test_name,
          code: t.test_code,
          price: t.price
        })),
        total_amount: subtotal
      },
      invoice: {
        _id: invoice[0]._id,
        total_amount: invoice[0].total_amount,
        payment_status: invoice[0].payment_status
        
      }
    });

  } catch (err) {
    await session.abortTransaction();
    console.error('Error requesting test for patient:', err);
    res.status(500).json({ error: err.message });
  } finally {
    session.endSession();
  }
};

// ✅ View Patient Test History
exports.getPatientTestHistory = async (req, res) => {
  try {
    const { patient_id } = req.params;
    const doctor_id = req.user.id;

    // Get all orders for this patient that were requested by this doctor
    const orders = await Order.find({
      patient_id,
      doctor_id: doctor_id  // Only show orders requested by this doctor
    })
      .populate('owner_id', 'name email phone_number')
      .populate('requested_by')
      .sort({ order_date: -1 });

    // Get order details with test info for each order
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code sample_type')
          .populate('staff_id', 'full_name');

        // Get results for completed tests
        const detailsWithResults = await Promise.all(
          details.map(async (detail) => {
            const result = await Result.findOne({ detail_id: detail._id });
            return {
              test_name: detail.test_id.test_name,
              test_code: detail.test_id.test_code,
              status: detail.status,
              sample_collected: detail.sample_collected,
              staff: detail.staff_id ? 
                `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}` : 
                'Not assigned',
              result: result ? {
                value: result.result_value,
                units: result.units,
                reference_range: result.reference_range,
                remarks: result.remarks
              } : null
            };
          })
        );

        return {
          order_id: order._id,
          order_date: order.order_date,
          status: order.status,
          remarks: order.remarks,
          lab: order.owner_id ? 
            `${order.owner_id.name.first} ${order.owner_id.name.last}` : 
            'N/A',
          requested_by: order.requested_by_model,
          tests: detailsWithResults
        };
      })
    );

    res.json({
      success: true,
      patient_id,
      orders: ordersWithDetails
    });

  } catch (err) {
    console.error('Error fetching patient test history:', err);
    res.status(500).json({ message: err.message });
  }
};

// ✅ Mark Test Order as Urgent
exports.markTestUrgent = async (req, res) => {
  try {
    const { orderId } = req.params;
    const doctor_id = req.user.id;

    const order = await Order.findById(orderId);
    if (!order) return res.status(404).json({ message: 'Order not found' });

    // Verify doctor has access to this order
    if (order.doctor_id && order.doctor_id.toString() !== doctor_id) {
      return res.status(403).json({ 
        message: 'You can only mark your own orders as urgent' 
      });
    }

    // Update order
    order.remarks = 'urgent';
    order.status = 'processing'; // Ensure it's being processed
    await order.save();

    // Update all order details to urgent status
    await OrderDetails.updateMany(
      { order_id: order._id, status: { $ne: 'completed' } },
      { $set: { status: 'urgent' } }
    );

    // Notify lab owner
    await Notification.create({
      sender_id: doctor_id,
      sender_model: 'Doctor',
      receiver_id: order.owner_id,
      receiver_model: 'Owner',
      type: 'request',
      title: '🚨 Order Marked as URGENT',
      message: `Order ${order._id} has been marked as URGENT by doctor. Immediate processing required.`
    });

    // Notify all lab staff
    const Staff = require('../models/Staff');
    const labStaff = await Staff.find({ owner_id: order.owner_id });
    
    const staffNotifications = labStaff.map(staff => ({
      sender_id: doctor_id,
      sender_model: 'Doctor',
      receiver_id: staff._id,
      receiver_model: 'Staff',
      type: 'request',
      title: '🚨 URGENT Order',
      message: `Order ${order._id} marked as URGENT. Please prioritize.`
    }));

    if (staffNotifications.length > 0) {
      await Notification.insertMany(staffNotifications);
    }

    res.json({ 
      success: true,
      message: '✅ Order marked as urgent and notifications sent',
      order: {
        _id: order._id,
        status: order.status,
        remarks: order.remarks
      }
    });

  } catch (err) {
    console.error('Error marking order as urgent:', err);
    res.status(500).json({ message: err.message });
  }
};
// ✅ Get all notifications for Doctor and mark unread as read
exports.getNotifications = async (req, res) => {
  try {
    const doctor_id = req.params.doctor_id;

    // Fetch all notifications for this doctor
    const notifications = await Notification.find({ receiver_id: doctor_id, receiver_model: "Doctor" })
      .sort({ createdAt: -1 }); // newest first

    // Mark unread notifications as read
    await Notification.updateMany(
      { receiver_id: doctor_id, receiver_model: "Doctor", is_read: false },
      { $set: { is_read: true } }
    );

    res.json({
      message: "Notifications retrieved successfully",
      notifications
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


// ✅ Get count of unread notifications (for real-time dashboard)
exports.getUnreadNotificationsCount = async (req, res) => {
  try {
    const doctor_id = req.user.id;

    const unreadCount = await Notification.countDocuments({
      receiver_id: doctor_id,
      receiver_model: "Doctor",
      is_read: false
    });

    res.json({ unreadCount });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};




// ✅ Get Available Labs
exports.getAvailableLabs = async (req, res) => {
  try {
    const labs = await LabOwner.find({ 
      status: 'approved',
      is_active: true 
    })
    .select('owner_id name email phone_number address');

    res.json({
      success: true,
      count: labs.length,
      labs: labs.map(lab => ({
        _id: lab._id,
        owner_id: lab.owner_id,
        name: `${lab.name.first} ${lab.name.middle || ''} ${lab.name.last}`.trim(),
        email: lab.email,
        phone: lab.phone_number,
        address: lab.address
      }))
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ Get Available Tests for a Lab
exports.getLabTests = async (req, res) => {
  try {
    const { lab_id } = req.params;

    const tests = await Test.find({ 
      owner_id: lab_id,
      is_active: true 
    })
    .select('test_code test_name sample_type tube_type price units reference_range turnaround_time')
    .sort('test_name');

    res.json({
      success: true,
      count: tests.length,
      tests
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ Search Patients (by name, email, or ID)
exports.searchPatients = async (req, res) => {
  try {
    const { query } = req.query;

    if (!query || query.length < 2) {
      return res.status(400).json({ 
        message: 'Please provide at least 2 characters to search' 
      });
    }

    const patients = await Patient.find({
      $or: [
        { 'full_name.first': { $regex: query, $options: 'i' } },
        { 'full_name.last': { $regex: query, $options: 'i' } },
        { email: { $regex: query, $options: 'i' } },
        { identity_number: { $regex: query, $options: 'i' } },
        { patient_id: { $regex: query, $options: 'i' } }
      ]
    })
    .select('patient_id full_name email phone_number identity_number birthday gender')
    .limit(20);

    res.json({
      success: true,
      count: patients.length,
      patients: patients.map(p => ({
        _id: p._id,
        patient_id: p.patient_id,
        name: `${p.full_name.first} ${p.full_name.middle || ''} ${p.full_name.last}`.trim(),
        email: p.email,
        phone: p.phone_number,
        identity_number: p.identity_number,
        birthday: p.birthday,
        gender: p.gender
      }))
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ List Patients under Care (patients for whom doctor has ordered tests)
exports.getPatients = async (req, res) => {
  try {
    const doctor_id = req.user.id;

    // Find all unique patients this doctor has ordered tests for
    const orders = await Order.find({ doctor_id })
      .distinct('patient_id');

    const patientRecords = await Patient.find({ _id: { $in: orders } })
      .select('patient_id full_name email phone_number identity_number birthday gender address blood_type allergies medical_history');

    res.json({ 
      success: true,
      count: patientRecords.length,
      patients: patientRecords.map(p => ({
        _id: p._id,
        patient_id: p.patient_id,
        full_name: p.full_name,
        name: `${p.full_name.first} ${p.full_name.middle || ''} ${p.full_name.last}`.trim(),
        email: p.email,
        phone: p.phone_number,
        identity_number: p.identity_number,
        birthday: p.birthday,
        gender: p.gender,
        address: p.address,
        blood_type: p.blood_type,
        allergies: p.allergies,
        medical_history: p.medical_history
      }))
    });

  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Get Patient Details
exports.getPatientDetails = async (req, res) => {
  try {
    const { patient_id } = req.params;
    const doctor_id = req.user.id;

    // Verify doctor has access to this patient (has ordered tests for them)
    const hasAccess = await Order.findOne({ doctor_id, patient_id });
    if (!hasAccess) {
      return res.status(403).json({ 
        message: 'You do not have access to this patient\'s details' 
      });
    }

    const patient = await Patient.findById(patient_id)
      .select('patient_id full_name email phone_number identity_number birthday gender address blood_type allergies medical_history date_of_birth');

    if (!patient) {
      return res.status(404).json({ message: 'Patient not found' });
    }

    res.json({
      success: true,
      patient: {
        _id: patient._id,
        patient_id: patient.patient_id,
        full_name: patient.full_name,
        email: patient.email,
        phone: patient.phone_number,
        identity_number: patient.identity_number,
        birthday: patient.birthday,
        date_of_birth: patient.date_of_birth,
        gender: patient.gender,
        address: patient.address,
        blood_type: patient.blood_type,
        allergies: patient.allergies,
        medical_history: patient.medical_history
      }
    });

  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ==================== Doctor Dashboard ====================
exports.getDashboard = async (req, res) => {
  try {
    const doctor_id = req.user.id;

    // Run all queries in parallel
    const [totalPatients, totalOrders, pendingOrders, urgentOrders, completedOrders, unreadNotifications] = await Promise.all([
      // Total unique patients under this doctor
      Order.distinct('patient_id', { doctor_id }).then(arr => arr.length),

      // Total orders by this doctor
      Order.countDocuments({ doctor_id }),

      // Pending/Processing orders
      Order.countDocuments({ doctor_id, status: { $in: ['pending', 'processing'] } }),

      // Urgent orders
      Order.countDocuments({ doctor_id, remarks: 'urgent', status: { $ne: 'completed' } }),

      // Completed orders
      Order.countDocuments({ doctor_id, status: 'completed' }),

      // Unread notifications
      Notification.countDocuments({ receiver_id: doctor_id, receiver_model: 'Doctor', is_read: false })
    ]);

    // Get recent orders
    const recentOrders = await Order.find({ doctor_id })
      .populate('patient_id', 'full_name patient_id')
      .populate('owner_id', 'name')
      .sort({ order_date: -1 })
      .limit(5);

    res.json({
      success: true,
      dashboard: {
        totalPatients,
        totalOrders,
        pendingOrders,
        urgentOrders,
        completedOrders,
        unreadNotifications
      },
      recentOrders: recentOrders.map(order => ({
        order_id: order._id,
        patient: order.patient_id ? 
          `${order.patient_id.full_name.first} ${order.patient_id.full_name.last}` : 
          'N/A',
        lab: order.owner_id ? 
          `${order.owner_id.name.first} ${order.owner_id.name.last}` : 
          'N/A',
        status: order.status,
        is_urgent: order.remarks === 'urgent',
        order_date: order.order_date
      }))
    });

  } catch (err) {
    console.error('Error fetching doctor dashboard:', err);
    res.status(500).json({ message: err.message });
  }
};





// ✅ Give Feedback on a Lab/Test/Service/System
exports.provideFeedback = async (req, res) => {
  try {
    const { target_type, target_id, rating, message, is_anonymous } = req.body;
    const doctor_id = req.user.id;

    // Validate required fields
    if (!target_type || !rating || !message) {
      return res.status(400).json({
        message: 'Target type, rating, and message are required'
      });
    }

    // Validate rating range
    if (rating < 1 || rating > 5) {
      return res.status(400).json({ message: 'Rating must be between 1 and 5' });
    }

    // Validate target exists if target_id is provided
    if (target_id) {
      let targetExists = false;
      let targetModel;

      switch (target_type) {
        case 'lab':
          const Owner = require('../models/Owner');
          targetExists = await Owner.findById(target_id);
          targetModel = 'Owner';
          break;
        case 'test':
          const Test = require('../models/Test');
          targetExists = await Test.findById(target_id);
          targetModel = 'Test';
          break;
        case 'order':
          const Order = require('../models/Order');
          targetExists = await Order.findById(target_id);
          targetModel = 'Order';
          break;
        case 'service':
          // Service feedback doesn't need target validation
          targetExists = true;
          targetModel = null;
          break;
        default:
          return res.status(400).json({ message: 'Invalid target type' });
      }

      if (!targetExists) {
        return res.status(404).json({ message: 'Target not found' });
      }

    // Check for 28-day cooldown (users can submit feedback every 4 weeks)
    const twentyEightDaysAgo = new Date(Date.now() - 28 * 24 * 60 * 60 * 1000);
    const lastFeedback = await Feedback.findOne({
      user_id: doctor_id,
      createdAt: { $gte: twentyEightDaysAgo }
    }).sort({ createdAt: -1 });

    if (lastFeedback) {
      const daysUntilNext = Math.ceil((lastFeedback.createdAt.getTime() + 28 * 24 * 60 * 60 * 1000 - Date.now()) / (24 * 60 * 60 * 1000));
      return res.status(429).json({
        message: `⏳ You can submit feedback again in ${daysUntilNext} days. Feedback is limited to once every 4 weeks.`
      });
    }

      const feedback = await Feedback.create({
        user_id: doctor_id,
        user_model: 'Doctor',
        target_type,
        target_id,
        target_model,
        rating,
        message,
        is_anonymous: is_anonymous || false
      });

      // Notify lab owner about new feedback (if it's about a lab)
      if (target_type === 'lab') {
        await Notification.create({
          sender_id: doctor_id,
          sender_model: 'Doctor',
          receiver_id: target_id,
          receiver_model: 'Owner',
          type: 'feedback',
          title: 'New Feedback Received',
          message: `Dr. ${req.user.username} has provided feedback: ${rating} stars`
        });
      }
    } else {
      // System feedback
      const feedback = await Feedback.create({
        user_id: doctor_id,
        user_model: 'Doctor',
        target_type: 'system',
        rating,
        message,
        is_anonymous: is_anonymous || false
      });
    }

    res.status(201).json({
      success: true,
      message: "✅ Feedback submitted successfully"
    });
  } catch (err) {
    console.error('Error submitting feedback:', err);
    res.status(500).json({ message: err.message });
  }
};

// ✅ Get Doctor's Feedback History
exports.getMyFeedback = async (req, res) => {
  try {
    const doctor_id = req.user.id;
    const { page = 1, limit = 10, target_type } = req.query;

    const query = {
      user_id: doctor_id,
      user_model: 'Doctor'
    };

    if (target_type) {
      query.target_type = target_type;
    }

    const feedback = await Feedback.find(query)
    .populate('target_id', 'name lab_name test_name')
    .sort({ createdAt: -1 })
    .limit(limit * 1)
    .skip((page - 1) * limit);

    const total = await Feedback.countDocuments(query);

    res.json({
      success: true,
      feedback,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (err) {
    console.error('Error fetching feedback:', err);
    res.status(500).json({ message: err.message });
  }
};

// ✅ Get Patient Orders with Results Summary (for Doctor's Dashboard)
exports.getPatientOrdersWithResults = async (req, res) => {
  try {
    const doctor_id = req.user.id;
    const { search } = req.query;

    // Build query for orders requested by this doctor
    let orderQuery = {
      doctor_id: doctor_id,
      status: { $in: ['processing', 'completed', 'ready'] }
    };

    // If search query provided, find matching patients first
    if (search && search.trim()) {
      const searchRegex = new RegExp(search.trim(), 'i');
      const patients = await Patient.find({
        $or: [
          { 'full_name.first': searchRegex },
          { 'full_name.middle': searchRegex },
          { 'full_name.last': searchRegex }
        ]
      }).select('_id');
      
      const patientIds = patients.map(p => p._id);
      orderQuery.patient_id = { $in: patientIds };
    }

    // Get all orders with populated patient and owner info
    const orders = await Order.find(orderQuery)
      .populate('patient_id', 'full_name identity_number')
      .populate('owner_id', 'name address')
      .sort({ order_date: -1 });

    // For each order, get test counts and status
    const ordersWithSummary = await Promise.all(
      orders.map(async (order) => {
        const orderDetails = await OrderDetails.find({ order_id: order._id });
        
        const totalTests = orderDetails.length;
        const completedTests = orderDetails.filter(d => d.status === 'completed').length;
        const inProgressTests = orderDetails.filter(d => d.status === 'in_progress').length;
        const pendingTests = orderDetails.filter(d => d.status === 'pending').length;
        
        // Check if order has any results
        const hasResults = completedTests > 0;

        // Get patient full name
        const patient = order.patient_id;
        const patientFullName = patient ? 
          `${patient.full_name.first} ${patient.full_name.middle || ''} ${patient.full_name.last}`.trim() : 
          'Unknown';

        // Get lab info
        const lab = order.owner_id;
        const labName = lab ? `${lab.name.first} ${lab.name.last}` : 'N/A';
        const labAddress = lab?.address ? 
          `${lab.address.street || ''}, ${lab.address.city || ''}, ${lab.address.state || ''}`.trim() : 
          '';

        return {
          order_id: order._id,
          order_date: order.order_date,
          patient_name: patientFullName,
          patient_identity: patient?.identity_number || '',
          lab_name: labName,
          lab_address: labAddress,
          total_tests: totalTests,
          completed_tests: completedTests,
          in_progress_tests: inProgressTests,
          pending_tests: pendingTests,
          has_results: hasResults,
          remarks: order.remarks
        };
      })
    );

    res.json({
      success: true,
      orders: ordersWithSummary
    });

  } catch (err) {
    console.error('Error fetching patient orders:', err);
    res.status(500).json({ message: err.message });
  }
};

// ✅ Get Detailed Results for a Specific Order (for Doctor)
exports.getOrderResults = async (req, res) => {
  try {
    const doctor_id = req.user.id;
    const { orderId } = req.params;

    // Get the order and verify it belongs to this doctor
    const order = await Order.findOne({ _id: orderId, doctor_id: doctor_id })
      .populate('patient_id', 'full_name identity_number birthday gender phone_number email address')
      .populate('owner_id', 'name address phone_number email');

    if (!order) {
      return res.status(404).json({ message: 'Order not found or not authorized' });
    }

    // Get order details with test information
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code sample_type');

    // For each order detail, get the result if available
    const results = await Promise.all(
      orderDetails.map(async (detail) => {
        const result = await Result.findOne({ detail_id: detail._id });
        
        return {
          test_name: detail.test_id?.test_name || 'Unknown Test',
          test_code: detail.test_id?.test_code || '',
          sample_type: detail.test_id?.sample_type || '',
          status: detail.status,
          result_value: result?.result_value || null,
          units: result?.units || '',
          reference_range: result?.reference_range || '',
          is_abnormal: result?.is_abnormal || false,
          remarks: result?.remarks || '',
          createdAt: result?.createdAt || detail.createdAt
        };
      })
    );

    // Prepare patient info
    const patient = order.patient_id;
    const patientInfo = patient ? {
      full_name: `${patient.full_name.first} ${patient.full_name.middle || ''} ${patient.full_name.last}`.trim(),
      identity_number: patient.identity_number,
      birthday: patient.birthday,
      gender: patient.gender,
      phone_number: patient.phone_number,
      email: patient.email,
      address: patient.address
    } : null;

    // Prepare lab info
    const lab = order.owner_id;
    const labInfo = lab ? {
      name: `${lab.name.first} ${lab.name.last}`,
      address: lab.address ? 
        `${lab.address.street || ''}, ${lab.address.city || ''}, ${lab.address.state || ''}`.trim() : '',
      phone: lab.phone_number,
      email: lab.email
    } : null;

    res.json({
      success: true,
      order_id: order._id,
      order_date: order.order_date,
      status: order.status,
      remarks: order.remarks,
      patient: patientInfo,
      lab: labInfo,
      results: results
    });

  } catch (err) {
    console.error('Error fetching order results:', err);
    res.status(500).json({ message: err.message });
  }
};