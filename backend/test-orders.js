const mongoose = require('mongoose');
require('dotenv').config();

// Import models
const Order = require('./models/Order');
const OrderDetails = require('./models/OrderDetails');
const Patient = require('./models/Patient');
const Doctor = require('./models/Doctor');
const Staff = require('./models/Staff');
const Test = require('./models/Test');
const Result = require('./models/Result');

// Connect to MongoDB
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ MongoDB Connected');
  } catch (err) {
    console.error('❌ MongoDB Connection Error:', err.message);
    process.exit(1);
  }
};

// Fetch and display all orders with details
const fetchAllOrders = async () => {
  try {
    console.log('\n========================================');
    console.log('FETCHING ALL ORDERS FROM DATABASE');
    console.log('========================================\n');

    // Get all orders with populated references
    const orders = await Order.find()
      .populate('patient_id', 'full_name patient_id phone_number email identity_number')
      .populate('doctor_id', 'name phone_number email')
      .populate('requested_by')
      .sort({ order_date: -1 });

    console.log(`\n📋 Total Orders Found: ${orders.length}\n`);

    if (orders.length === 0) {
      console.log('No orders found in the database.');
      return;
    }

    // Iterate through each order
    for (let i = 0; i < orders.length; i++) {
      const order = orders[i];
      
      console.log(`\n${'='.repeat(80)}`);
      console.log(`ORDER #${i + 1}`);
      console.log(`${'='.repeat(80)}`);
      
      console.log('\n📦 ORDER INFORMATION:');
      console.log(`  Order ID: ${order._id}`);
      console.log(`  Order Date: ${order.order_date}`);
      console.log(`  Status: ${order.status}`);
      console.log(`  Barcode: ${order.barcode || 'Not generated yet'}`);
      console.log(`  Is Patient Registered: ${order.is_patient_registered}`);
      
      // Patient Information
      console.log('\n👤 PATIENT INFORMATION:');
      if (order.patient_id && order.patient_id.full_name) {
        console.log(`  Name: ${order.patient_id.full_name.first || ''} ${order.patient_id.full_name.middle || ''} ${order.patient_id.full_name.last || ''}`);
        console.log(`  Patient ID: ${order.patient_id.patient_id || 'N/A'}`);
        console.log(`  Phone: ${order.patient_id.phone_number || 'N/A'}`);
        console.log(`  Email: ${order.patient_id.email || 'N/A'}`);
        console.log(`  Identity Number: ${order.patient_id.identity_number || 'N/A'}`);
      } else if (order.temp_patient_info && order.temp_patient_info.full_name) {
        console.log(`  Name (Temporary): ${order.temp_patient_info.full_name.first || ''} ${order.temp_patient_info.full_name.middle || ''} ${order.temp_patient_info.full_name.last || ''}`);
        console.log(`  Phone: ${order.temp_patient_info.phone_number || 'N/A'}`);
        console.log(`  Email: ${order.temp_patient_info.email || 'N/A'}`);
        console.log(`  Identity Number: ${order.temp_patient_info.identity_number || 'N/A'}`);
        console.log(`  ⚠️  Patient not yet registered in system`);
      } else {
        console.log(`  ⚠️  No patient information available`);
      }

      // Doctor Information
      console.log('\n👨‍⚕️ DOCTOR INFORMATION:');
      if (order.doctor_id) {
        console.log(`  Name: ${order.doctor_id.name || 'N/A'}`);
        console.log(`  Phone: ${order.doctor_id.phone_number || 'N/A'}`);
        console.log(`  Email: ${order.doctor_id.email || 'N/A'}`);
      } else {
        console.log(`  No doctor assigned`);
      }

      // Requested By Information
      console.log('\n📝 REQUESTED BY:');
      if (order.requested_by_model) {
        console.log(`  Model: ${order.requested_by_model}`);
        if (order.requested_by) {
          if (order.requested_by_model === 'Patient') {
            console.log(`  Name: ${order.requested_by.full_name ? `${order.requested_by.full_name.first} ${order.requested_by.full_name.last}` : 'N/A'}`);
          } else if (order.requested_by_model === 'Doctor') {
            console.log(`  Name: ${order.requested_by.name || 'N/A'}`);
          }
        }
      } else {
        console.log(`  Not specified`);
      }

      // Address
      if (order.address) {
        console.log('\n📍 ADDRESS:');
        console.log(`  ${order.address.street || ''}`);
        console.log(`  ${order.address.city || ''}, ${order.address.state || ''} ${order.address.postal_code || ''}`);
        console.log(`  ${order.address.country || ''}`);
      }

      // Remarks
      if (order.remarks) {
        console.log('\n💬 REMARKS:');
        console.log(`  ${order.remarks}`);
      }

      // Get order details (tests)
      const orderDetails = await OrderDetails.find({ order_id: order._id })
        .populate('test_id', 'test_name test_code price category')
        .populate('staff_id', 'full_name employee_number role')
        .populate('device_id', 'name serial_number model');

      console.log('\n🧪 TESTS ORDERED:');
      console.log(`  Total Tests: ${orderDetails.length}`);
      
      if (orderDetails.length === 0) {
        console.log(`  ⚠️  No test details found for this order`);
      } else {
        for (let idx = 0; idx < orderDetails.length; idx++) {
          const detail = orderDetails[idx];
          console.log(`\n  ${'-'.repeat(70)}`);
          console.log(`  Test #${idx + 1}:`);
          console.log(`  ${'-'.repeat(70)}`);
          
          console.log(`    Detail ID: ${detail._id}`);
          console.log(`    Sample Barcode: ${detail.barcode || 'Not generated yet'}`);
          console.log(`    Status: ${detail.status}`);
          
          // Test Information
          if (detail.test_id) {
            console.log(`\n    🔬 Test Information:`);
            console.log(`      Name: ${detail.test_id.test_name || 'N/A'}`);
            console.log(`      Code: ${detail.test_id.test_code || 'N/A'}`);
            console.log(`      Price: $${detail.test_id.price || 0}`);
            console.log(`      Category: ${detail.test_id.category || 'N/A'}`);
          } else {
            console.log(`    ⚠️  Test information not available`);
          }

          // Staff Assignment
          if (detail.staff_id) {
            console.log(`\n    👷 Assigned Staff:`);
            console.log(`      Name: ${detail.staff_id.full_name ? `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}` : 'N/A'}`);
            console.log(`      Employee Number: ${detail.staff_id.employee_number || 'N/A'}`);
            console.log(`      Role: ${detail.staff_id.role || 'N/A'}`);
            console.log(`      Assigned At: ${detail.assigned_at || 'Not specified'}`);
          } else {
            console.log(`\n    👷 Assigned Staff: Not assigned yet`);
          }

          // Device Assignment
          if (detail.device_id) {
            console.log(`\n    🔧 Assigned Device:`);
            console.log(`      Name: ${detail.device_id.name || 'N/A'}`);
            console.log(`      Serial Number: ${detail.device_id.serial_number || 'N/A'}`);
            console.log(`      Model: ${detail.device_id.model || 'N/A'}`);
          } else {
            console.log(`\n    🔧 Assigned Device: Not assigned yet`);
          }

          // Sample Collection
          console.log(`\n    💉 Sample Collection:`);
          console.log(`      Collected: ${detail.sample_collected ? 'Yes' : 'No'}`);
          if (detail.sample_collected && detail.sample_collected_date) {
            console.log(`      Collection Date: ${detail.sample_collected_date}`);
          }

          // Fetch result for this test
          const result = await Result.findOne({ detail_id: detail._id });
          console.log(`\n    📊 Test Result:`);
          if (result) {
            console.log(`      Status: ✅ Available`);
            console.log(`      Result ID: ${result._id}`);
            console.log(`      Value: ${result.result_value || 'N/A'}`);
            console.log(`      Units: ${result.units || 'N/A'}`);
            console.log(`      Reference Range: ${result.reference_range || 'N/A'}`);
            if (result.remarks) {
              console.log(`      Remarks: ${result.remarks}`);
            }
            console.log(`      Created At: ${result.createdAt}`);
            console.log(`      Updated At: ${result.updatedAt}`);
          } else {
            console.log(`      Status: ⏳ Not available yet (test may not be completed)`);
          }

          console.log(`\n    Created At: ${detail.createdAt}`);
          console.log(`    Updated At: ${detail.updatedAt}`);
        }
      }

      console.log(`\n${'='.repeat(80)}\n`);
    }

    console.log('\n✅ Order fetch completed successfully!\n');

  } catch (error) {
    console.error('❌ Error fetching orders:', error);
  }
};

// Main execution
const main = async () => {
  await connectDB();
  await fetchAllOrders();
  await mongoose.connection.close();
  console.log('\n👋 Database connection closed. Goodbye!\n');
  process.exit(0);
};

// Run the script
main();
