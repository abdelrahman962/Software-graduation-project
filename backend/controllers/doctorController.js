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
const jwt = require('jsonwebtoken');
const sendEmail = require('../utils/sendEmail');
const sendSMS = require('../utils/sendSMS');

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

    // Create order (within transaction) - barcode will be generated when sample collected
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
      order_id: newOrder[0]._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'pending',
      owner_id
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

    await sendEmail(patient.email, emailSubject, emailMessage);
    await sendSMS(patient.phone_number, `Dr. ${req.user.username} ordered ${test_ids.length} test(s) for you${is_urgent ? ' (URGENT)' : ''}. Visit ${lab.lab_name} for sample collection. Tests: ${tests.map(t => t.test_name).join(', ')}`);

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

    // Get all orders for this patient
    const orders = await Order.find({ patient_id })
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
          barcode: order.barcode,
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
    const { order_id } = req.params;
    const doctor_id = req.user.id;

    const order = await Order.findById(order_id);
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
      message: `Order ${order.barcode} has been marked as URGENT by doctor. Immediate processing required.`
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
      message: `Order ${order.barcode} marked as URGENT. Please prioritize.`
    }));

    if (staffNotifications.length > 0) {
      await Notification.insertMany(staffNotifications);
    }

    res.json({ 
      success: true,
      message: '✅ Order marked as urgent and notifications sent',
      order: {
        _id: order._id,
        barcode: order.barcode,
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
      .sort({ created_at: -1 }); // newest first

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
      .select('patient_id full_name email phone_number identity_number birthday gender');

    res.json({ 
      success: true,
      count: patientRecords.length,
      patients: patientRecords.map(p => ({
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
        barcode: order.barcode,
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





// // ✅ Give Feedback on a Lab/Test
// exports.provideFeedback = async (req, res) => {
//   try {
//     const { doctor_id, lab_id, message, rating } = req.body;

//     const feedback = await Feedback.create({
//       user_id: doctor_id,
//       lab_id,
//       message,
//       rating,
//       type: "doctor",
//       created_at: new Date(),
//     });

//     res.status(201).json({ message: "Feedback submitted", feedback });
//   } catch (err) {
//     res.status(500).json({ message: err.message });
//   }
// };