const mongoose = require('mongoose');

const testSchema = new mongoose.Schema({
  test_code: { type: String, required: true },
  test_name: { type: String, required: true },
  sample_type: String,
  tube_type: String,
  is_active: { type: Boolean, default: true },
  device_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Device' },
  method: { type: String, enum: ['manual','device'] },
  units: String,
  reference_range: String,
  price: Number,
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner', required: true },
  turnaround_time: String,
  created_at: { type: Date, default: Date.now },
  collection_time: String,
  reagent: String
});

module.exports = mongoose.model('TestManagement', testSchema);
