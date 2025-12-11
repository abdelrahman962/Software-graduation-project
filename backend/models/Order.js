const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  // Patient reference (optional initially - filled when staff registers patient)
  patient_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Patient',
    required: true
  },
  address: require('./schemas/addressSchema'),
  
  // Temporary patient info (for orders submitted before patient registration)
  temp_patient_info: {
    full_name: {
      first: String,
      middle: String,
      last: String
    },
    identity_number: String,
    email: String,
    phone_number: String,
    birthday: Date,
    gender: String,
    address: String
  },
  
  // Who requested this order (flexible reference using refPath)
  requested_by: { type: mongoose.Schema.Types.ObjectId, refPath: 'requested_by_model' },
  requested_by_model: { 
    type: String, 
    enum: ['Patient', 'Doctor'],
    default: null
  },
  
  doctor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Doctor' },  // If doctor is involved
  order_date: { type: Date, default: Date.now },
  status: { type: String, enum: ['pending','processing','completed'], default: 'pending' },
  remarks: String,
  barcode: { type: String, unique: true, sparse: true },  // Sparse allows null values, generated when sample collected
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner', required: true },
  
  // Track if patient has been registered
  is_patient_registered: { type: Boolean, default: false },
  
  // Account registration token for email/SMS link
  registration_token: { type: String, unique: true, sparse: true },
  registration_token_expires: { type: Date }
}, {
  timestamps: true
});

// Remove duplicate index - unique constraint already creates an index
// orderSchema.index({ barcode: 1 });

// Helper function to generate unique barcode
orderSchema.statics.generateUniqueBarcode = async function() {
  let barcode;
  let exists = true;
  
  while (exists) {
    // Format: ORD-TIMESTAMP-RANDOM (e.g., ORD-1731456789000-A3B9)
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    barcode = `ORD-${timestamp}-${random}`;
    
    // Check if barcode already exists
    exists = await this.findOne({ barcode });
  }
  
  return barcode;
};

// Helper function to validate and set frontend-generated barcode
orderSchema.statics.validateAndSetBarcode = async function(orderId, frontendBarcode) {
  // Validate barcode format
  const barcodeRegex = /^ORD-\d{13}-[A-Z0-9]{4}$/;
  if (!barcodeRegex.test(frontendBarcode)) {
    throw new Error('Invalid barcode format');
  }

  // Check if barcode already exists
  const existingOrder = await this.findOne({ barcode: frontendBarcode });
  if (existingOrder && existingOrder._id.toString() !== orderId.toString()) {
    throw new Error('Barcode already exists');
  }

  // Update the order with the frontend-generated barcode
  await this.findByIdAndUpdate(orderId, { barcode: frontendBarcode });
  return frontendBarcode;
};

// Helper function to generate registration token
orderSchema.statics.generateRegistrationToken = function() {
  const crypto = require('crypto');
  return crypto.randomBytes(32).toString('hex');
};

module.exports = mongoose.model('Orders', orderSchema);
