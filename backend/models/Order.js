const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  patient_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Patient', required: true },
  requested_by: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },  // If staff creates the order
  doctor_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Doctor' },  // If doctor requests for patient
  order_date: { type: Date, default: Date.now },
  status: { type: String, enum: ['processing','completed'], default: 'processing' },
  remarks: String,
  barcode: String,
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner', required: true }
});

module.exports = mongoose.model('Orders', orderSchema);
