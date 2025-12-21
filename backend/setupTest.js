require('dotenv').config();
const mongoose = require('mongoose');
const Notification = require('./models/Notification');
const Admin = require('./models/Admin');
const Owner = require('./models/Owner');
// Require other models to register them
require('./models/Patient');
require('./models/Doctor');
require('./models/Staff');

// Connect to DB
mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('DB Connected'))
  .catch(err => console.error('DB Error:', err));

async function setupTestUsers() {
  try {
    // Create or update admin
    let admin = await Admin.findOne({ phone_number: '+972594317447' });
    if (!admin) {
      admin = new Admin({
        full_name: { first: 'Test', last: 'Admin' },
        phone_number: '+972594317447',
        email: 'admin@test.com',
        username: 'testadmin',
        password: '$2a$10$examplehashedpassword', // Pre-hashed for test
        identity_number: '123456789',
        birthday: new Date('1990-01-01'),
        gender: 'Male',
        admin_id: 'ADM001'
      });
      await admin.save();
      console.log('Admin created');
    } else {
      console.log('Admin exists');
    }

    // Create or update owner
    let owner = await Owner.findOne({ phone_number: '+972594301103' });
    if (!owner) {
      owner = new Owner({
        name: { first: 'Test', last: 'Owner' },
        phone_number: '+972594301103',
        email: 'owner@test.com',
        username: 'testowner',
        password: '$2a$10$examplehashedpassword',
        identity_number: '987654321',
        birthday: new Date('1985-01-01'),
        gender: 'Male',
        lab_name: 'Test Lab',
        admin_id: admin._id, // Reference to admin
        status: 'approved', // To allow username/password
        social_status: 'Single',
        owner_id: 'OWN001', // Unique ID
        address: {
          country: 'Test',
          city: 'Test City',
          street: 'Test Street',
          building: '1'
        }
      });
      await owner.save();
      console.log('Owner created');
    } else {
      console.log('Owner exists');
    }

    // Create a notification from owner to admin
    const notification = new Notification({
      sender_id: owner._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      title: 'Test Message',
      message: 'This is a test message from owner to admin.',
      is_read: false
    });
    await notification.save();
    console.log('Notification created for testing webhook');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

setupTestUsers();