const mongoose = require('mongoose');

const LabOwnerSchema = new mongoose.Schema({
  owner_id: { type: Number, required: true, unique: true },
  name: {
    first: String,
    middle: String,
    last: String
  },
  identity_number: String,
  birthday: Date,
  gender: String,
  social_status: String,
  phone_number: String,
  address: String,
  qualification: String,
  profession_license: String,
  bank_iban: String,
  email: String,
  username: String,
  password: String,
  date_subscription: { type: Date, default: Date.now },
  admin_id: Number,

  // ➕ Add these two fields for subscription tracking
  subscription_end: { type: Date },              // subscription expiry date
  is_active: { type: Boolean, default: true }    // whether lab is active
});

module.exports = mongoose.model('LabOwner', LabOwnerSchema);
