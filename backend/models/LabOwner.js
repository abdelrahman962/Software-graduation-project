const mongoose = require('mongoose');

const labOwnerSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true, // full name: first, middle, last
  },
  identity_number: {
    type: String,
    required: true,
    unique: true
  },
  birthday: {
    type: Date,
    required: true
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other'],
    required: true
  },
  social_status: {
    type: String,
    enum: ['single', 'married', 'divorced', 'widowed'],
    required: false
  },
  phone_number: {
    type: String,
    required: true
  },
  address: {
    type: String,
    required: true
  },
  qualification: {
    type: String,
    required: true
  },
  profession_license: {
    type: String,
    required: true
  },
  owner_id: {
    type: String,
    required: true,
    unique: true
  },
  bank_iban: {
    type: String,
    required: true
  },
  email: {
    type: String,
    required: true,
    unique: true
  },
  username: {
    type: String,
    required: true,
    unique: true
  },
  password: {
    type: String,
    required: true
  },
  date_subscription: {
    type: Date,
    default: Date.now
  },
  admin_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Admin',
    required: false
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'reject'],
    default: 'pending'
  },
  is_active: {
    type: Boolean,
    default: true
  },
  subscription_end: {
    type: Date
  }
}, { timestamps: true });

module.exports = mongoose.model('labowners', labOwnerSchema);
