require('dotenv').config();
const mongoose = require('mongoose');
const Staff = require('./models/Staff');
const Admin = require('./models/Admin');
const Owner = require('./models/Owner');
const Doctor = require('./models/Doctor');

// Connect to DB
mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('DB Connected'))
  .catch(err => console.error('DB Error:', err));

async function changePassword() {
  try {
    const username = 'ahmed.staff';
    const newPassword = 'StrongPassword123!';

    // Check in all user models
    let user = await Staff.findOne({ username });
    let model = 'Staff';

    if (!user) {
      user = await Admin.findOne({ username });
      model = 'Admin';
    }
    if (!user) {
      user = await Owner.findOne({ username });
      model = 'Owner';
    }
    if (!user) {
      user = await Doctor.findOne({ username });
      model = 'Doctor';
    }

    if (!user) {
      console.log('User not found');
      process.exit(1);
    }

    console.log(`Found user in ${model}: ${user.username}`);

    // Update password (will be hashed by pre-save hook)
    user.password = newPassword;
    await user.save();

    console.log('Password updated successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

changePassword();