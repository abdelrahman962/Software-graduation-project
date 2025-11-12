const bcrypt = require('bcryptjs');

async function hashPassword() {
  const newPassword = 'StrongPassword123!'; // staff password & amin password
  const hashed = await bcrypt.hash(newPassword, 10);
  console.log('Hashed password:', hashed);
}

hashPassword();


/*
{
  "full_name": {
    "first": "Sara",
    "middle": "Ali",
    "last": "Mohamed"
  },
  "identity_number": "29501234567890",
  "birthday": "1995-03-20",
  "gender": "Female",
  "social_status": "Single",
  "phone_number": "+201555444333",
  "address": "Ramallah, Palestine",
  "qualification": "Bachelor of Medical Laboratory Sciences",
  "email": "sara.staff@example.com",
  "username": "Sara Mohammed",
  "password": "Staff@123"
} */