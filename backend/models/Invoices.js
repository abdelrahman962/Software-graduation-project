const mongoose = require('mongoose');

const invoiceSchema = new mongoose.Schema({
  order_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Orders' },
  invoice_date: { type: Date, default: Date.now },
  subtotal: Number,
  discount: Number,
  total_amount: Number,
  payment_status: { type: String, enum: ['pending','paid','partial'], default: 'pending' },
  payment_method: { type: String, enum: ['cash','card','bank_transfer'] },
  paid_by: String,
  remarks: String,
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner' }
});

module.exports = mongoose.model('Invoices', invoiceSchema);
