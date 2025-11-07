const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const patientSchema = new mongoose.Schema({
  full_name: { 
    first: { type: String, required: true }, 
    middle: String, 
    last: { type: String, required: true } 
  },
  identity_number: { type: String, required: true, unique: true },
  birthday: Date,
  gender: { type: String, enum: ['Male', 'Female', 'Other'] },
  social_status: { type: String, enum: ['Single', 'Married', 'Divorced', 'Widowed'] },
  phone_number: String,
  address: String,
  patient_id: { type: String, unique: true },
  insurance_provider: String,
  insurance_number: String,
  notes: String,
  email: { type: String, unique: true },
  username: { type: String, unique: true },
  password: { type: String, required: true },
  created_by_staff: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  created_at: { type: Date, default: Date.now },
  last_login: Date
}, {
  timestamps: true
});

// Hash password before saving
patientSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to compare password
patientSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model('Patient', patientSchema);
