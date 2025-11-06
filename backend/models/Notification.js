const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  sender_id: { type: mongoose.Schema.Types.ObjectId, refPath: 'sender_model' }, // new
  sender_model: { type: String, enum: ['Admin', 'Owner', 'Doctor', 'Patient','Staff'] }, // new

  receiver_id: { type: mongoose.Schema.Types.ObjectId, refPath: 'receiver_model' },
  receiver_model: { type: String, enum: ['Owner', 'Patient', 'Doctor','Admin','Staff'], required: true },

  type: { type: String, enum: ['subscription', 'system', 'maintenance', 'test_result'], default: 'subscription' },
  title: String,
  message: String,
  related_id: { type: mongoose.Schema.Types.ObjectId }, 
  is_read: { type: Boolean, default: false },
  created_at: { type: Date, default: Date.now }
});
module.exports = mongoose.model('Notification', NotificationSchema);