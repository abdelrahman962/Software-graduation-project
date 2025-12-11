const mongoose = require('mongoose');
require('dotenv').config();

const LabOwner = require('./models/Owner');

const testLabsAPI = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // Simulate the exact API call
    const labs = await LabOwner.find({
      status: 'approved',
      is_active: true
    })
    .select('lab_name email phone_number address subscription_end_date')
    .lean();

    console.log(`\nFound ${labs.length} approved/active labs`);

    const apiResponse = {
      success: true,
      count: labs.length,
      labs: labs.map(lab => ({
        _id: lab._id,
        lab_name: lab.lab_name,
        email: lab.email,
        phone_number: lab.phone_number,
        address: lab.address,
        subscription_active: lab.subscription_end_date > new Date()
      }))
    };

    console.log('\n=== API RESPONSE ===');
    console.log(JSON.stringify(apiResponse, null, 2));

    console.log('\n=== LABS ARRAY DETAILS ===');
    apiResponse.labs.forEach((lab, index) => {
      console.log(`${index + 1}. ID: ${lab._id}`);
      console.log(`   lab_name: "${lab.lab_name}"`);
      console.log(`   email: "${lab.email}"`);
      console.log(`   phone_number: "${lab.phone_number}"`);
      console.log(`   address:`, lab.address);
      console.log(`   subscription_active: ${lab.subscription_active}`);
      console.log('   ---');
    });

  } catch (error) {
    console.error('Error:', error);
  } finally {
    await mongoose.connection.close();
  }
};

testLabsAPI();