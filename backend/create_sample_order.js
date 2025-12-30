const mongoose = require('mongoose');
require('dotenv').config();

// Connect to MongoDB
async function connectDB() {
  try {
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/medlab');
    console.log('✅ Connected to MongoDB');
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
    process.exit(1);
  }
}

// Models
const Test = require('./models/Test');
const Patient = require('./models/Patient');
const Order = require('./models/Order');
const OrderDetails = require('./models/OrderDetails');
const Invoice = require('./models/Invoices');
const Staff = require('./models/Staff');
const LabOwner = require('./models/Owner');
const { Inventory } = require('./models/Inventory');

// Sample data
const samplePatient = {
  patient_id: 'TEST001',
  username: 'testpatient',
  password: 'testpass123',
  full_name: {
    first: 'Test',
    last: 'Patient'
  },
  identity_number: '123456789',
  birthday: new Date('1990-01-01'),
  gender: 'male',
  social_status: 'single',
  phone_number: '+972501234567',
  email: 'test.patient@example.com',
  address: {
    street: '123 Test St',
    city: 'Test City',
    country: 'Israel'
  },
  insurance_provider: 'Test Insurance',
  insurance_number: 'INS123456',
  is_active: true
};

async function createSampleData() {
  try {
    console.log('🏥 Creating sample patient order with test and invoice...\n');

    // 1. Get first available lab owner
    const labOwner = await LabOwner.findOne();
    if (!labOwner) {
      console.log('❌ No lab owner found. Please create a lab owner first.');
      return;
    }
    console.log(`📋 Using Lab: ${labOwner.lab_name}`);

    // 2. Get first available staff member
    const staff = await Staff.findOne({ owner_id: labOwner._id });
    if (!staff) {
      console.log('❌ No staff member found for this lab.');
      return;
    }
    console.log(`👨‍⚕️ Using Staff: ${staff.name.first} ${staff.name.last}`);

    // 3. Get first available test
    const test = await Test.findOne({ owner_id: labOwner._id });
    if (!test) {
      console.log('❌ No tests found for this lab.');
      return;
    }
    console.log(`🧪 Using Test: ${test.test_name} (${test.test_code}) - ₪${test.price}`);

    // 4. Create or find patient
    let patient = await Patient.findOne({ username: samplePatient.username });
    if (!patient) {
      patient = await Patient.create(samplePatient);
      console.log('✅ New patient created');
    } else {
      console.log('✅ Using existing patient');
    }
    console.log(`👤 Patient: ${patient.full_name.first} ${patient.full_name.last} (${patient.patient_id})`);

    // 5. Create order
    const order = await Order.create({
      owner_id: labOwner._id,
      patient_id: patient._id,
      doctor_id: null,
      order_date: new Date(),
      status: 'processing',
      is_patient_registered: true,
      requested_by: staff._id
    });
    console.log(`📋 Order created: ${order._id}`);

    // 6. Create order details
    const orderDetail = await OrderDetails.create({
      order_id: order._id,
      test_id: test._id,
      status: 'pending',
      staff_id: staff._id
    });
    console.log(`📝 Order detail created for test: ${test.test_name}`);

    // 7. Create invoice
    const invoiceCount = await Invoice.countDocuments();
    const invoiceId = `INV-${String(invoiceCount + 1).padStart(6, '0')}`;

    const invoice = await Invoice.create({
      invoice_id: invoiceId,
      order_id: order._id,
      invoice_date: new Date(),
      subtotal: test.price,
      discount: 0,
      total_amount: test.price,
      payment_status: 'paid',
      payment_method: 'cash',
      payment_date: new Date(),
      paid_by: staff._id,
      owner_id: labOwner._id,
      items: [{
        test_id: test._id,
        test_name: test.test_name,
        price: test.price,
        quantity: 1
      }]
    });
    console.log(`🧾 Invoice created: ${invoice.invoice_id} - ₪${invoice.total_amount} (${invoice.payment_status})`);

    // 8. Summary
    console.log('\n🎉 Complete patient order workflow successful!');
    console.log('=' .repeat(50));
    console.log(`Patient ID: ${patient.patient_id}`);
    console.log(`Patient Name: ${patient.full_name.first} ${patient.full_name.last}`);
    console.log(`Order ID: ${order._id}`);
    console.log(`Order Date: ${order.order_date.toLocaleDateString()}`);
    console.log(`Test: ${test.test_name} (${test.test_code})`);
    console.log(`Price: ₪${test.price}`);
    console.log(`Invoice: ${invoice.invoice_id}`);
    console.log(`Total Paid: ₪${invoice.total_amount}`);
    console.log(`Payment Method: ${invoice.payment_method}`);
    console.log('=' .repeat(50));

  } catch (error) {
    console.error('❌ Error creating sample data:', error);
  } finally {
    await mongoose.connection.close();
    console.log('📪 Database connection closed');
  }
}

// Create sample inventory for ahmed.staff's lab owner
async function createSampleInventory() {
  try {
    console.log('📦 Creating sample inventory items...\n');

    // Find ahmed.staff and get their owner_id
    const staff = await Staff.findOne({ username: 'ahmed.staff' });
    if (!staff) {
      console.log('❌ Staff member "ahmed.staff" not found.');
      return;
    }

    const ownerId = staff.owner_id;
    console.log(`👨‍⚕️ Found staff: ${staff.full_name.first} ${staff.full_name.last} (${staff.username})`);
    console.log(`🏥 Owner ID: ${ownerId}`);

    // Sample inventory items
    const sampleInventory = [
      {
        name: 'Chemical Reagents',
        item_code: 'CHEM-001',
        cost: 25.50,
        expiration_date: new Date('2026-06-15'),
        critical_level: 10,
        count: 50,
        balance: 50,
        owner_id: ownerId
      },
      {
        name: 'Blood Collection Tubes',
        item_code: 'TUBE-001',
        cost: 5.75,
        expiration_date: new Date('2026-12-31'),
        critical_level: 20,
        count: 100,
        balance: 100,
        owner_id: ownerId
      },
      {
        name: 'Gloves (Box of 100)',
        item_code: 'GLOVE-001',
        cost: 12.00,
        expiration_date: new Date('2027-03-20'),
        critical_level: 5,
        count: 25,
        balance: 25,
        owner_id: ownerId
      },
      {
        name: 'Test Strips',
        item_code: 'STRIP-001',
        cost: 8.25,
        expiration_date: new Date('2026-08-10'),
        critical_level: 15,
        count: 75,
        balance: 75,
        owner_id: ownerId
      },
      {
        name: 'Microscope Slides',
        item_code: 'SLIDE-001',
        cost: 15.00,
        expiration_date: new Date('2027-01-15'),
        critical_level: 30,
        count: 200,
        balance: 200,
        owner_id: ownerId
      }
    ];

    // Create inventory items
    const createdItems = [];
    for (const item of sampleInventory) {
      const existingItem = await Inventory.findOne({
        item_code: item.item_code,
        owner_id: ownerId
      });

      if (!existingItem) {
        const newItem = await Inventory.create(item);
        createdItems.push(newItem);
        console.log(`✅ Created: ${newItem.name} (${newItem.item_code}) - ${newItem.count} units`);
      } else {
        console.log(`⚠️  Skipped: ${item.name} (${item.item_code}) - already exists`);
      }
    }

    console.log(`\n🎉 Created ${createdItems.length} new inventory items for the lab!`);

  } catch (error) {
    console.error('❌ Error creating inventory:', error);
  } finally {
    await mongoose.connection.close();
    console.log('📪 Database connection closed');
  }
}

// List available data
async function listAvailableData() {
  try {
    console.log('📊 Available Data in Database:\n');

    const labOwners = await LabOwner.find({}, 'lab_name email');
    console.log(`🏥 Lab Owners (${labOwners.length}):`);
    labOwners.forEach(owner => console.log(`  - ${owner.lab_name} (${owner.email})`));

    const staff = await Staff.find({}, 'full_name username owner_id');
    console.log(`\n👨‍⚕️ Staff Members (${staff.length}):`);
    staff.forEach(s => console.log(`  - ${s.full_name.first} ${s.full_name.last} (${s.username})`));

    const tests = await Test.find({}, 'test_name test_code price owner_id');
    console.log(`\n🧪 Tests (${tests.length}):`);
    tests.forEach(test => console.log(`  - ${test.test_name} (${test.test_code}) - ₪${test.price}`));

    const patients = await Patient.find({}, 'patient_id full_name username');
    console.log(`\n👤 Patients (${patients.length}):`);
    patients.forEach(p => console.log(`  - ${p.patient_id}: ${p.full_name.first} ${p.full_name.last} (${p.username})`));

    const inventory = await Inventory.find({}, 'name item_code count critical_level owner_id');
    console.log(`\n📦 Inventory Items (${inventory.length}):`);
    inventory.forEach(item => console.log(`  - ${item.name} (${item.item_code}) - ${item.count} units (critical: ${item.critical_level})`));

  } catch (error) {
    console.error('❌ Error listing data:', error);
  } finally {
    await mongoose.connection.close();
  }
}

// Main execution
async function main() {
  await connectDB();

  const args = process.argv.slice(2);

  if (args.includes('--list')) {
    await listAvailableData();
  } else if (args.includes('--create')) {
    await createSampleData();
  } else if (args.includes('--inventory')) {
    await createSampleInventory();
  } else {
    console.log('Usage:');
    console.log('  node create_sample_order.js --list       # List available data');
    console.log('  node create_sample_order.js --create     # Create sample order');
    console.log('  node create_sample_order.js --inventory  # Create sample inventory for ahmed.staff\'s lab');
  }
}

if (require.main === module) {
  main();
}

module.exports = { createSampleData, listAvailableData };