const mongoose = require('mongoose');

const orderDetailSchema = new mongoose.Schema({
  order_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Orders' },
  test_id: { type: mongoose.Schema.Types.ObjectId, ref: 'TestManagement' },
  
  // Sample barcode for security and relationship tracking
  barcode: { type: String, unique: true, sparse: true },
  
  // Device assignment
  device_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Device' },
  
  // Staff assignment (auto-assigned based on device)
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  assigned_at: { type: Date },
  
  // Sample collection tracking
  sample_collected: { type: Boolean, default: false },
  sample_collected_date: { type: Date },
  
  status: { 
    type: String, 
    enum: ['pending', 'assigned', 'urgent', 'collected', 'in_progress', 'completed'], 
    default: 'pending' 
  }
}, {
  timestamps: true
});

// Index for staff querying their assigned tests
orderDetailSchema.index({ staff_id: 1, status: 1 });

// Index for device-based queries
orderDetailSchema.index({ device_id: 1, status: 1 });

// Helper function to generate unique sample barcode
orderDetailSchema.statics.generateUniqueSampleBarcode = async function() {
  let barcode;
  let exists = true;
  
  while (exists) {
    // Format: SMP-TIMESTAMP-RANDOM (e.g., SMP-1731456789000-A3B9)
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    barcode = `SMP-${timestamp}-${random}`;
    
    // Check if barcode already exists
    exists = await this.findOne({ barcode });
  }
  
  return barcode;
};

// Helper function to validate and set frontend-generated sample barcode
orderDetailSchema.statics.validateAndSetSampleBarcode = async function(detailId, frontendBarcode) {
  // Validate barcode format
  const barcodeRegex = /^SMP-\d{13}-[A-Z0-9]{4}$/;
  if (!barcodeRegex.test(frontendBarcode)) {
    throw new Error('Invalid sample barcode format');
  }

  // Check if barcode already exists
  const existingDetail = await this.findOne({ barcode: frontendBarcode });
  if (existingDetail && existingDetail._id.toString() !== detailId.toString()) {
    throw new Error('Sample barcode already exists');
  }

  // Update the order detail with the frontend-generated barcode
  await this.findByIdAndUpdate(detailId, { barcode: frontendBarcode });
  return frontendBarcode;
};

module.exports = mongoose.model('OrderDetails', orderDetailSchema);
