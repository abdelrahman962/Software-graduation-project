const mongoose = require('mongoose');
require('dotenv').config();

async function checkAndRemoveUncompletedOrders() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to database');

    const Order = require('./models/Order');
    const OrderDetails = require('./models/OrderDetails');
    const Invoices = require('./models/Invoices');
    const Result = require('./models/Result');
    const ResultComponent = require('./models/ResultComponent');

    // Get all orders
    const orders = await Order.find({})
      .populate('patient_id', 'full_name')
      .sort({ order_date: -1 });

    console.log('\n=== ALL ORDERS ===');
    orders.forEach(o => {
      console.log(`- ID: ${o._id}, Status: ${o.status}, Patient: ${o.patient_id?.full_name?.first} ${o.patient_id?.full_name?.last}, Date: ${o.order_date}`);
    });

    // Find uncompleted orders
    const uncompletedOrders = orders.filter(o => o.status !== 'completed');
    console.log(`\n=== UNCOMPLETED ORDERS: ${uncompletedOrders.length} ===`);

    if (uncompletedOrders.length === 0) {
      console.log('No uncompleted orders found.');
      process.exit(0);
    }

    // Show uncompleted orders
    uncompletedOrders.forEach(o => {
      console.log(`- ID: ${o._id}, Status: ${o.status}, Patient: ${o.patient_id?.full_name?.first} ${o.patient_id?.full_name?.last}`);
    });

    // Ask for confirmation (in a real script, you'd use readline)
    console.log('\n⚠️  This will permanently delete the uncompleted orders and all related data!');
    console.log('Related data includes: OrderDetails, Invoices, Results, ResultComponents');

    // For now, let's just show what would be deleted
    console.log('\n=== WHAT WILL BE DELETED ===');

    for (const order of uncompletedOrders) {
      const orderDetails = await OrderDetails.find({ order_id: order._id });
      const invoices = await Invoices.find({ order_id: order._id });
      const results = await Result.find({ order_id: order._id });
      const resultComponents = await ResultComponent.find({
        result_id: { $in: results.map(r => r._id) }
      });

      console.log(`\nOrder ${order._id}:`);
      console.log(`  - ${orderDetails.length} order details`);
      console.log(`  - ${invoices.length} invoices`);
      console.log(`  - ${results.length} results`);
      console.log(`  - ${resultComponents.length} result components`);
    }

    console.log('\n=== TO ACTUALLY DELETE, uncomment the deletion code below ===');
    console.log('// Uncomment the following lines to actually delete:');

    /*
    console.log('\n🗑️  DELETING UNCOMPLETED ORDERS...');

    for (const order of uncompletedOrders) {
      // Delete related data first
      const results = await Result.find({ order_id: order._id });
      const resultIds = results.map(r => r._id);

      await ResultComponent.deleteMany({ result_id: { $in: resultIds } });
      await Result.deleteMany({ order_id: order._id });
      await Invoices.deleteMany({ order_id: order._id });
      await OrderDetails.deleteMany({ order_id: order._id });
      await Order.findByIdAndDelete(order._id);

      console.log(`✅ Deleted order ${order._id}`);
    }

    console.log('\n🎉 All uncompleted orders removed successfully!');
    */

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkAndRemoveUncompletedOrders();