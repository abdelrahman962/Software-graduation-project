const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ownerSchema = new mongoose.Schema({
  owner_id: { 
    type: Number, 
    required: true, 
    unique: true 
  },
  name: {
    first: { type: String, required: true },
    middle: { type: String },
    last: { type: String, required: true }
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
    enum: ['Male', 'Female', 'Other'],
    required: true 
  },
  social_status: { 
    type: String, 
    enum: ['Single', 'Married', 'Divorced', 'Widowed'] 
  },
  phone_number: { 
    type: String, 
    required: true 
  },
  address: { 
    type: String 
  },
  qualification: { 
    type: String 
  },
  profession_license: { 
    type: String 
  },
  bank_iban: { 
    type: String 
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
    type: mongoose.Schema.Types.ObjectId, ref: "Admin", required: true 
  },
  subscription_end: { 
    type: Date 
  },
  is_active: { 
    type: Boolean, 
    default: false 
  },
  status: { 
    type: String, 
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  }
}, {
  timestamps: true
});

// Hash password before saving
ownerSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Method to compare password
ownerSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model('LabOwner', ownerSchema);
