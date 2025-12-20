const mongoose = require('mongoose');
require('dotenv').config();

// Import all models
const Owner = require('./models/Owner');
const Staff = require('./models/Staff');
const { Inventory } = require('./models/Inventory');
const Device = require('./models/Device');
const Test = require('./models/Test');
const TestComponent = require('./models/TestComponent');
const Patient = require('./models/Patient');
const Order = require('./models/Order');
const OrderDetails = require('./models/OrderDetails');
const Result = require('./models/Result');
const ResultComponent = require('./models/ResultComponent');
const Admin = require('./models/Admin');
const Doctor = require('./models/Doctor');

async function setupLabData() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // Clear existing data first (except admin)
    console.log('Clearing existing data...');
    await Promise.all([
      Owner.deleteMany({}),
      Staff.deleteMany({}),
      Inventory.deleteMany({}),
      Device.deleteMany({}),
      Test.deleteMany({}),
      TestComponent.deleteMany({}),
      Patient.deleteMany({}),
      Order.deleteMany({}),
      OrderDetails.deleteMany({}),
      Result.deleteMany({}),
      ResultComponent.deleteMany({})
    ]);
    console.log('Existing data cleared');

    // 1. Get existing admin (don't create new one)
    const admin = await Admin.findOne();
    if (!admin) {
      console.log('No admin found. Please ensure admin exists first.');
      return;
    }
    console.log('Using existing admin:', admin.email);

    // 2. Create lab owner
    const ownerData = {
      name: { first: 'Abdelrahman', middle: 'Masri', last: 'Owner' },
      identity_number: '1234567890123',
      birthday: new Date('1980-01-01'),
      gender: 'Male',
      phone_number: '+972594317447',
      email: 's12112958@stu.najah.edu',
      address: {
        street: '123 Main St',
        city: 'Nablus',
        state: 'West Bank',
        zip_code: '12345',
        country: 'Palestine'
      },
      lab_name: 'Advanced Medical Lab',
      lab_license_number: 'LAB-2024-001',
      username: 'abdelrahman.owner',
      password: 'owner123',
      admin_id: admin._id,
      is_active: true,
      status: 'approved',
      subscriptionFee: 100,
      subscription_period_months: 12,
      subscription_end: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year
    };

    const owner = await Owner.create(ownerData);
    console.log('Created lab owner:', owner.lab_name);

    // 3. Create staffs
    const staffsData = [
      {
        full_name: { first: 'Ahmed', middle: 'Ali', last: 'Staff' },
        identity_number: '1111111111111',
        birthday: new Date('1990-05-15'),
        gender: 'Male',
        phone_number: '+972501234567',
        email: 'ahmed.staff@lab.com',
        address: {
          street: '456 Staff St',
          city: 'Nablus',
          state: 'West Bank',
          zip_code: '12345',
          country: 'Palestine'
        },
        username: 'ahmed.staff',
        password: 'staff123',
        owner_id: owner._id,
        salary: 3000,
        qualification: 'Medical Laboratory Technician',
        profession_license: 'MLT-001',
        employee_number: 'EMP-001'
      },
      {
        full_name: { first: 'Fatima', middle: 'Omar', last: 'Staff' },
        identity_number: '2222222222222',
        birthday: new Date('1988-08-20'),
        gender: 'Female',
        phone_number: '+972509876543',
        email: 'fatima.staff@lab.com',
        address: {
          street: '789 Staff Ave',
          city: 'Nablus',
          state: 'West Bank',
          zip_code: '12345',
          country: 'Palestine'
        },
        username: 'fatima.staff',
        password: 'staff123',
        owner_id: owner._id,
        salary: 3200,
        qualification: 'Clinical Laboratory Scientist',
        profession_license: 'CLS-002',
        employee_number: 'EMP-002'
      },
      {
        full_name: { first: 'Mohammed', middle: 'Hassan', last: 'Staff' },
        identity_number: '3333333333333',
        birthday: new Date('1992-03-10'),
        gender: 'Male',
        phone_number: '+972507654321',
        email: 'mohammed.staff@lab.com',
        address: {
          street: '321 Tech St',
          city: 'Nablus',
          state: 'West Bank',
          zip_code: '12345',
          country: 'Palestine'
        },
        username: 'mohammed.staff',
        password: 'staff123',
        owner_id: owner._id,
        salary: 2800,
        qualification: 'Laboratory Assistant',
        profession_license: 'LA-003',
        employee_number: 'EMP-003'
      }
    ];

    const staffs = [];
    for (const staffData of staffsData) {
      const staff = await Staff.create(staffData);
      staffs.push(staff);
      console.log('Created staff:', staff.full_name.first, staff.full_name.last);
    }

    // 4. Create inventories
    const inventoriesData = [
      {
        name: 'Blood Collection Tubes',
        item_code: 'BCT-001',
        cost: 5.50,
        expiration_date: new Date('2025-12-31'),
        critical_level: 50,
        count: 200,
        balance: 200,
        owner_id: owner._id
      },
      {
        name: 'Glucose Test Strips',
        item_code: 'GTS-002',
        cost: 15.00,
        expiration_date: new Date('2025-06-30'),
        critical_level: 20,
        count: 100,
        balance: 100,
        owner_id: owner._id
      },
      {
        name: 'Urine Test Strips',
        item_code: 'UTS-003',
        cost: 8.00,
        expiration_date: new Date('2025-08-15'),
        critical_level: 30,
        count: 150,
        balance: 150,
        owner_id: owner._id
      },
      {
        name: 'Microscope Slides',
        item_code: 'MS-004',
        cost: 2.50,
        expiration_date: new Date('2026-01-01'),
        critical_level: 100,
        count: 500,
        balance: 500,
        owner_id: owner._id
      },
      {
        name: 'Chemical Reagents',
        item_code: 'CR-005',
        cost: 25.00,
        expiration_date: new Date('2025-09-30'),
        critical_level: 10,
        count: 50,
        balance: 50,
        owner_id: owner._id
      }
    ];

    const inventories = [];
    for (const invData of inventoriesData) {
      const inventory = await Inventory.create(invData);
      inventories.push(inventory);
      console.log('Created inventory:', inventory.name);
    }

    // 5. Create devices
    const devicesData = [
      {
        name: 'Automated Blood Analyzer',
        serial_number: 'ABA-2024-001',
        manufacturer: 'Siemens',
        status: 'active',
        staff_id: staffs[0]._id, // Ahmed
        capacity_of_sample: 100,
        maintenance_schedule: 'weekly',
        owner_id: owner._id,
        cleaning_reagent: 'Isopropyl Alcohol'
      },
      {
        name: 'Urine Analyzer',
        serial_number: 'UA-2024-002',
        manufacturer: 'Roche',
        status: 'active',
        staff_id: staffs[1]._id, // Fatima
        capacity_of_sample: 50,
        maintenance_schedule: 'daily',
        owner_id: owner._id,
        cleaning_reagent: 'Distilled Water'
      },
      {
        name: 'Microscope',
        serial_number: 'MIC-2024-003',
        manufacturer: 'Olympus',
        status: 'active',
        staff_id: staffs[2]._id, // Mohammed
        capacity_of_sample: 1,
        maintenance_schedule: 'monthly',
        owner_id: owner._id,
        cleaning_reagent: 'Lens Cleaner'
      }
    ];

    const devices = [];
    for (const deviceData of devicesData) {
      const device = await Device.create(deviceData);
      devices.push(device);
      console.log('Created device:', device.name);
    }

    // 6. Create tests with components
    const testsData = [
      {
        test_code: 'CBC',
        test_name: 'Complete Blood Count',
        sample_type: 'Blood',
        tube_type: 'EDTA Tube',
        device_id: devices[0]._id,
        method: 'Automated Hematology',
        units: 'Various',
        reference_range: 'See individual components',
        price: 50,
        owner_id: owner._id,
        turnaround_time: '2 hours',
        collection_time: '8:00 AM - 6:00 PM',
        reagent: 'Hematology Reagent Kit',
        components: [
          { component_name: 'White Blood Cells', component_code: 'WBC', units: '×10³/μL', reference_range: '4.0-11.0', min_value: 4.0, max_value: 11.0 },
          { component_name: 'Red Blood Cells', component_code: 'RBC', units: '×10⁶/μL', reference_range: '4.2-5.4', min_value: 4.2, max_value: 5.4 },
          { component_name: 'Hemoglobin', component_code: 'HGB', units: 'g/dL', reference_range: '12.0-16.0', min_value: 12.0, max_value: 16.0 },
          { component_name: 'Hematocrit', component_code: 'HCT', units: '%', reference_range: '36.0-46.0', min_value: 36.0, max_value: 46.0 },
          { component_name: 'Platelets', component_code: 'PLT', units: '×10³/μL', reference_range: '150-450', min_value: 150, max_value: 450 }
        ]
      },
      {
        test_code: 'LFT',
        test_name: 'Liver Function Test',
        sample_type: 'Blood',
        tube_type: 'Serum Tube',
        device_id: devices[0]._id,
        method: 'Biochemical Analysis',
        units: 'Various',
        reference_range: 'See individual components',
        price: 75,
        owner_id: owner._id,
        turnaround_time: '4 hours',
        collection_time: '8:00 AM - 6:00 PM',
        reagent: 'Liver Panel Reagent',
        components: [
          { component_name: 'ALT', component_code: 'ALT', units: 'U/L', reference_range: '7-56', min_value: 7, max_value: 56 },
          { component_name: 'AST', component_code: 'AST', units: 'U/L', reference_range: '10-40', min_value: 10, max_value: 40 },
          { component_name: 'ALP', component_code: 'ALP', units: 'U/L', reference_range: '44-147', min_value: 44, max_value: 147 },
          { component_name: 'Total Bilirubin', component_code: 'TBIL', units: 'mg/dL', reference_range: '0.3-1.2', min_value: 0.3, max_value: 1.2 },
          { component_name: 'Direct Bilirubin', component_code: 'DBIL', units: 'mg/dL', reference_range: '0.0-0.3', min_value: 0.0, max_value: 0.3 }
        ]
      },
      {
        test_code: 'UA',
        test_name: 'Urine Analysis',
        sample_type: 'Urine',
        tube_type: 'Urine Container',
        device_id: devices[1]._id,
        method: 'Automated Urinalysis',
        units: 'Various',
        reference_range: 'See individual components',
        price: 30,
        owner_id: owner._id,
        turnaround_time: '1 hour',
        collection_time: '8:00 AM - 6:00 PM',
        reagent: 'Urine Reagent Strips',
        components: [
          { component_name: 'Color', component_code: 'COLOR', units: '', reference_range: 'Yellow', min_value: null, max_value: null },
          { component_name: 'Appearance', component_code: 'APPEAR', units: '', reference_range: 'Clear', min_value: null, max_value: null },
          { component_name: 'Specific Gravity', component_code: 'SG', units: '', reference_range: '1.003-1.030', min_value: 1.003, max_value: 1.030 },
          { component_name: 'pH', component_code: 'PH', units: '', reference_range: '4.5-8.0', min_value: 4.5, max_value: 8.0 },
          { component_name: 'Protein', component_code: 'PROT', units: 'mg/dL', reference_range: 'Negative', min_value: null, max_value: null }
        ]
      },
      {
        test_code: 'GLU',
        test_name: 'Blood Glucose',
        sample_type: 'Blood',
        tube_type: 'Fluoride Tube',
        device_id: devices[0]._id,
        method: 'Enzymatic Method',
        units: 'mg/dL',
        reference_range: '70-140',
        price: 25,
        owner_id: owner._id,
        turnaround_time: '30 minutes',
        collection_time: '8:00 AM - 6:00 PM',
        reagent: 'Glucose Reagent',
        components: [
          { component_name: 'Glucose', component_code: 'GLU', units: 'mg/dL', reference_range: '70-140', min_value: 70, max_value: 140 }
        ]
      }
    ];

    const tests = [];
    for (const testData of testsData) {
      const { components, ...testInfo } = testData;
      const test = await Test.create(testInfo);
      tests.push(test);

      // Create components for this test
      for (const componentData of components) {
        await TestComponent.create({
          test_id: test._id,
          ...componentData
        });
      }
      console.log('Created test:', test.test_name, 'with', components.length, 'components');
    }

    // 7. Create patient
    const patientData = {
      full_name: { first: 'Test', middle: 'Patient', last: 'User' },
      identity_number: '9876543210987',
      birthday: new Date('1995-06-15'),
      gender: 'Male',
      phone_number: '+972501112223',
      address: {
        street: '123 Patient St',
        city: 'Nablus',
        state: 'West Bank',
        zip_code: '12345',
        country: 'Palestine'
      },
      email: 'abdelrahmanmasri3@gmail.com',
      username: 'test.patient',
      password: 'patient123'
    };

    const patient = await Patient.create(patientData);
    console.log('Created patient:', patient.full_name.first, patient.full_name.last);

    // 8. Create order with multiple tests
    const order = await Order.create({
      patient_id: patient._id,
      order_date: new Date(),
      status: 'processing',
      owner_id: owner._id,
      is_patient_registered: true
    });

    console.log('Created order with ID:', order._id);

    // 9. Create order details and assign staff
    const orderDetailsData = [
      { test_id: tests[0]._id, staff_id: staffs[0]._id }, // CBC -> Ahmed
      { test_id: tests[1]._id, staff_id: staffs[1]._id }, // LFT -> Fatima
      { test_id: tests[2]._id, staff_id: staffs[1]._id }, // UA -> Fatima
      { test_id: tests[3]._id, staff_id: staffs[2]._id }  // GLU -> Mohammed
    ];

    const orderDetails = [];
    for (const detailData of orderDetailsData) {
      const detail = await OrderDetails.create({
        order_id: order._id,
        ...detailData,
        status: 'completed',
        sample_collected: true,
        sample_collected_date: new Date()
      });
      orderDetails.push(detail);
    }

    console.log('Created order details and assigned staff to each test');

    // 10. Upload results for each test
    for (const detail of orderDetails) {
      const test = tests.find(t => t._id.toString() === detail.test_id.toString());
      const staff = staffs.find(s => s._id.toString() === detail.staff_id.toString());

      // Get components for this test
      const components = await TestComponent.find({ test_id: test._id });

      if (components.length > 0) {
        // Complex test with components
        const result = await Result.create({
          detail_id: detail._id,
          staff_id: staff._id,
          has_components: true,
          is_abnormal: false,
          abnormal_components_count: 0
        });

        // Create result components with sample values
        for (const component of components) {
          let componentValue = '';
          let isAbnormal = false;

          // Generate sample values based on component
          switch (component.component_code) {
            case 'WBC': componentValue = '7.5'; break;
            case 'RBC': componentValue = '4.8'; break;
            case 'HGB': componentValue = '14.2'; break;
            case 'HCT': componentValue = '42.0'; break;
            case 'PLT': componentValue = '280'; break;
            case 'ALT': componentValue = '25'; break;
            case 'AST': componentValue = '30'; break;
            case 'ALP': componentValue = '85'; break;
            case 'TBIL': componentValue = '0.8'; break;
            case 'DBIL': componentValue = '0.2'; break;
            case 'COLOR': componentValue = 'Yellow'; break;
            case 'APPEAR': componentValue = 'Clear'; break;
            case 'SG': componentValue = '1.015'; break;
            case 'PH': componentValue = '6.5'; break;
            case 'PROT': componentValue = 'Negative'; break;
            case 'GLU': componentValue = '95'; break;
            default: componentValue = 'Normal';
          }

          // Check if abnormal
          if (component.min_value !== null && component.max_value !== null) {
            const value = parseFloat(componentValue);
            if (!isNaN(value) && (value < component.min_value || value > component.max_value)) {
              isAbnormal = true;
            }
          }

          await ResultComponent.create({
            result_id: result._id,
            component_id: component._id,
            component_name: component.component_name,
            component_value: componentValue,
            units: component.units,
            reference_range: component.reference_range,
            is_abnormal: isAbnormal
          });

          if (isAbnormal) {
            result.is_abnormal = true;
            result.abnormal_components_count += 1;
          }
        }

        await result.save();
        console.log(`Uploaded results for ${test.test_name} by ${staff.full_name.first} ${staff.full_name.last}`);
      } else {
        // Simple test without components
        await Result.create({
          detail_id: detail._id,
          staff_id: staff._id,
          result_value: 'Normal',
          units: test.units,
          reference_range: test.reference_range,
          is_abnormal: false
        });
        console.log(`Uploaded simple result for ${test.test_name} by ${staff.full_name.first} ${staff.full_name.last}`);
      }
    }

    // Update order status to completed
    order.status = 'completed';
    await order.save();

    console.log('\n✅ Lab setup completed successfully!');
    console.log('=====================================');
    console.log('Owner Email:', owner.email);
    console.log('Patient Email:', patient.email);
    console.log('Owner Login: abdelrahman.owner / owner123');
    console.log('Patient Login: test.patient / patient123');
    console.log('Staff Logins:');
    staffs.forEach(staff => {
      console.log(`  ${staff.username} / staff123`);
    });
    console.log('=====================================');

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error setting up lab data:', error);
    await mongoose.disconnect();
    process.exit(1);
  }
}

setupLabData();