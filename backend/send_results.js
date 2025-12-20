const mongoose = require('mongoose');
require('dotenv').config();

// Import models and utilities
const Order = require('./models/Order');
const OrderDetails = require('./models/OrderDetails');
const Result = require('./models/Result');
const ResultComponent = require('./models/ResultComponent');
const Test = require('./models/Test');
const TestComponent = require('./models/TestComponent');
const Patient = require('./models/Patient');
const Owner = require('./models/Owner');
const Staff = require('./models/Staff');
const { sendOrderResults } = require('./utils/sendNotification');

async function sendOrderResultsToPatient() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // Find the order we created
    const order = await Order.findOne({}).populate('patient_id owner_id');
    if (!order) {
      console.log('No order found');
      return;
    }

    console.log('Found order:', order._id);
    console.log('Patient:', order.patient_id.email);
    console.log('Owner:', order.owner_id.email);

    // Get all order details with populated data
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id')
      .populate('staff_id');

    console.log(`Found ${orderDetails.length} order details`);

    // Check if all tests are completed
    const allCompleted = orderDetails.every(detail => detail.status === 'completed');

    if (!allCompleted) {
      console.log('Not all tests are completed yet. Waiting for all results before sending notification.');
      const completedCount = orderDetails.filter(detail => detail.status === 'completed').length;
      console.log(`Completed: ${completedCount}/${orderDetails.length} tests`);
      await mongoose.disconnect();
      return;
    }

    console.log('All tests completed! Sending comprehensive order results notification...');

    // Send comprehensive order results notification
    const notificationSuccess = await sendOrderResults(
      order.patient_id,
      order,
      order.owner_id,
      orderDetails
    );

    if (notificationSuccess.whatsapp.success && notificationSuccess.email.success) {
      console.log('✅ Order results notification sent successfully via both WhatsApp and Email');
    } else {
      console.log('⚠️ Partial success:');
      if (notificationSuccess.whatsapp.success) {
        console.log('  ✅ WhatsApp sent successfully');
      } else {
        console.log('  ❌ WhatsApp failed:', notificationSuccess.whatsapp.error);
      }
      if (notificationSuccess.email.success) {
        console.log('  ✅ Email sent successfully');
      } else {
        console.log('  ❌ Email failed:', notificationSuccess.email.error);
      }
    }

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error sending order results:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

sendOrderResultsToPatient();