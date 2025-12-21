require('dotenv').config();
const mongoose = require('mongoose');
const Patient = require('./models/Patient');
const Doctor = require('./models/Doctor');
const Staff = require('./models/Staff');
const LabOwner = require('./models/Owner');
const Admin = require('./models/Admin');

async function checkAllUsers() {
  try {
    await mongoose.connect(process.env.MONGO_URI);

    const user = await Patient.findOne({ $or: [{ username: 'ahmed.staff' }, { email: 'ahmed.staff' }] });
    if (user) console.log('Found in Patient:', user.username, user.email);

    const user2 = await Doctor.findOne({ $or: [{ username: 'ahmed.staff' }, { email: 'ahmed.staff' }] });
    if (user2) console.log('Found in Doctor:', user2.username, user2.email);

    const user3 = await Staff.findOne({ $or: [{ username: 'ahmed.staff' }, { email: 'ahmed.staff' }] });
    if (user3) console.log('Found in Staff:', user3.username, user3.email);

    const user4 = await LabOwner.findOne({ $or: [{ username: 'ahmed.staff' }, { email: 'ahmed.staff' }] });
    if (user4) console.log('Found in LabOwner:', user4.username, user4.email);

    const user5 = await Admin.findOne({ $or: [{ username: 'ahmed.staff' }, { email: 'ahmed.staff' }] });
    if (user5) console.log('Found in Admin:', user5.username, user5.email);

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await mongoose.disconnect();
  }
}

checkAllUsers();