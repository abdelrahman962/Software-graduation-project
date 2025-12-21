require('dotenv').config();
const mongoose = require('mongoose');
const Patient = require('./models/Patient');
const Doctor = require('./models/Doctor');
const Staff = require('./models/Staff');
const LabOwner = require('./models/Owner');
const Admin = require('./models/Admin');

async function testUnifiedLogin() {
  try {
    await mongoose.connect(process.env.MONGO_URI);

    const username = 'ahmed.staff';
    const password = 'StrongPassword123!';

    // Normalize username for staff
    const normalizedUsername = username.replace(/\s+/g, '.').toLowerCase();
    console.log('Normalized username:', normalizedUsername);

    // Try each user type
    const userTypes = [
      { model: Patient, role: 'patient' },
      { model: Doctor, role: 'doctor' },
      { model: Staff, role: 'Staff' },
      { model: LabOwner, role: 'owner' },
      { model: Admin, role: 'admin' }
    ];

    for (const userType of userTypes) {
      console.log(`Checking ${userType.role}...`);

      // For staff, use normalized username
      const searchUsername = userType.role === 'staff' ? normalizedUsername : username;
      console.log(`Search username: ${searchUsername}`);

      const user = await userType.model.findOne({
        $or: [{ username: searchUsername }, { email: username }]
      });

      if (user) {
        console.log(`Found user in ${userType.role}: ${user.username}`);

        // Check password
        const isMatch = await user.comparePassword(password);
        console.log(`Password match: ${isMatch}`);

        if (isMatch) {
          console.log('Login successful!');
          return;
        }
      } else {
        console.log(`No user found in ${userType.role}`);
      }
    }

    console.log('No valid login found');

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await mongoose.disconnect();
  }
}

testUnifiedLogin();