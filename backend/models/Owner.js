const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ownerSchema = new mongoose.Schema({
  owner_id: { 
    type:String, 
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
  address: require('./schemas/addressSchema'),
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

// Normalize username before saving
ownerSchema.pre('save', function(next) {
  if (this.isModified('username')) {
    // Remove spaces and convert to lowercase
    this.username = this.username.replace(/\s+/g, '.').toLowerCase();
  }
  next();
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
