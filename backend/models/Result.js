const mongoose = require('mongoose');

const resultSchema = new mongoose.Schema({
  detail_id: { type: mongoose.Schema.Types.ObjectId, ref: 'OrderDetails' },
  result_value: String,
  units: String,
  reference_range: String,
  remarks: String
});

module.exports = mongoose.model('Results', resultSchema);
