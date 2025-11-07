const Doctor = require('../models/Doctor');
const Patient = require('../models/Patient');
const TestOrder = require('../models/Test');
const OrderDetail = require('../models/OrderDetails');
const Result = require('../models/Result');
const Notification = require('../models/Notification');
const jwt = require('jsonwebtoken');

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

// ✅ View Patient Test History
exports.getPatientTestHistory = async (req, res) => {
  try {
    const { patient_id } = req.params;

    const orders = await TestOrder.find({ patient_id })
      .populate({
        path: 'details',
        populate: [{ path: 'test_id' }, { path: 'staff_id' }, { path: 'results' }]
      });

    res.json({ patient_id, orders });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ✅ Mark Test Order as Urgent
exports.markTestUrgent = async (req, res) => {
  try {
    const { order_id } = req.params;
    const doctor_id = req.user.id;

    const order = await TestOrder.findById(order_id);
    if (!order) return res.status(404).json({ message: 'Order not found' });

    order.remarks = 'urgent';
    await order.save();

    // Notify assigned staff
    await Notification.create({
      sender_id: doctor_id,
      sender_model: 'Doctor',
      receiver_model: 'Staff',
      receiver_id: order.assigned_staff, // assuming field exists
      type: 'urgent_test',
      title: 'Urgent Test Request',
      message: `Order ${order_id} marked as urgent by Dr. ${req.user.username}`
    });

    res.json({ message: 'Test marked as urgent', order });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
exports.getNotifications = async (req, res) => {
  try {
    const { doctor_id } = req.params;
    const notifications = await Notification.find({ receiver_id: doctor_id, receiver_model: "Doctor" });
    res.json(notifications);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};



// ✅ List Patients under Care
exports.getPatients = async (req, res) => {
  try {
    const { doctor_id } = req.params;

    // Find all orders by this doctor
    const orders = await TestOrder.find({ doctor_id }).populate("patient_id");
    const patients = [...new Set(orders.map(o => o.patient_id._id.toString()))];

    const patientRecords = await Patient.find({ _id: { $in: patients } });

    res.json({ patients: patientRecords });
  } catch (err) {
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