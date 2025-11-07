const mongoose = require('mongoose');

const orderDetailSchema = new mongoose.Schema({
  order_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Orders' },
  test_id: { type: mongoose.Schema.Types.ObjectId, ref: 'TestManagement' },
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  sample_collected: { type: Boolean, default: false },
  status: { type: String, enum: ['pending','in_progress','completed'], default: 'pending' }
});

module.exports = mongoose.model('OrderDetails', orderDetailSchema);
