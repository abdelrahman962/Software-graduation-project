const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const addressSchema = require('./schemas/addressSchema');

const staffSchema = new mongoose.Schema({
  full_name: {
    first: { type: String, required: true },
    middle: { type: String },
    last: { type: String, required: true }
  },
  identity_number: { type: String, required: true, unique: true },
  birthday: { type: Date, required: true },
  gender: { type: String, enum: ["Male", "Female", "Other"], required: true },
  social_status: { type: String, enum: ["Single", "Married", "Divorced", "Widowed"] },
  phone_number: { type: String, required: true },
  address: addressSchema,
  qualification: { type: String },
  profession_license: { type: String },
  employee_number: { type: String, unique: true },
  bank_iban: { type: String },
  salary: { type: Number, default: 0 },
  employee_evaluation: { type: String },
  email: { type: String, required: true, unique: true },
  username: { 
    type: String, 
    required: true, 
    unique: true,
    lowercase: true,
    trim: true,
    validate: {
      validator: function(v) {
        return /^[a-z0-9._-]+$/.test(v);
      },
      message: 'Username can only contain lowercase letters, numbers, dots, underscores, and hyphens (no spaces)'
    }
  },
  password: { type: String, required: true },
  date_hired: { type: Date, default: Date.now },
  last_login: { type: Date },
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: "LabOwner", required: true },
  login_history: [{ type: Date }]
});

// Normalize username before saving
staffSchema.pre("save", function (next) {
  if (this.isModified("username")) {
    // Remove spaces and convert to lowercase
    this.username = this.username.replace(/\s+/g, '.').toLowerCase();
  }
  next();
});

// Hash password before saving
staffSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

staffSchema.methods.comparePassword = async function (password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model("Staff", staffSchema);
