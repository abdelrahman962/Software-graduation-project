const mongoose = require('mongoose');

const orderDetailSchema = new mongoose.Schema({
  order_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Orders' },
  test_id: { type: mongoose.Schema.Types.ObjectId, ref: 'TestManagement' },
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  sample_collected_date: { type: Date },
  status: { 
    type: String, 
    enum: ['pending', 'urgent', 'collected', 'in_progress', 'completed'], 
    default: 'pending' 
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('OrderDetails', orderDetailSchema);
