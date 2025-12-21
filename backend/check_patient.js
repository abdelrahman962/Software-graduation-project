const mongoose = require('mongoose');
const Patient = require('./models/Patient');
const Order = require('./models/Order');

async function checkPatientOrder() {
  try {
    await mongoose.connect('mongodb+srv://Abdelrahman:Abood1842003@abdelrahman.v3kl9.mongodb.net/lab_management?retryWrites=true&w=majority');

    // Check for the correct email
    const patient = await Patient.findOne({ email: 'motaz.qarmash19@gmail.com' });

    if (!patient) {
      console.log('Patient with email motaz.qarmash19@gmail.com not found');
      return;
    }

    console.log('Patient found:', {
      _id: patient._id,
      full_name: patient.full_name,
      email: patient.email,
      patient_id: patient.patient_id
    });

    const orders = await Order.find({ patient_id: patient._id })
      .sort({ order_date: -1 });

    console.log('\nFound ' + orders.length + ' orders for this patient:');

    orders.forEach((order, index) => {
      console.log('Order ' + (index + 1) + ':', {
        order_id: order._id,
        order_date: order.order_date,
        status: order.status,
        doctor_id: order.doctor_id || 'No doctor assigned',
        owner_id: order.owner_id || 'No lab assigned'
      });
    });

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await mongoose.disconnect();
  }
}

checkPatientOrder();