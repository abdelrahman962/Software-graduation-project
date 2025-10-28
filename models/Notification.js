const NotificationSchema = new mongoose.Schema({
  sender_id: { type: mongoose.Schema.Types.ObjectId, refPath: 'sender_model' }, // new
  sender_model: { type: String, enum: ['Admin', 'LabOwner', 'Doctor', 'Patient'] }, // new

  receiver_id: { type: mongoose.Schema.Types.ObjectId, refPath: 'receiver_model' },
  receiver_model: { type: String, enum: ['LabOwner', 'Patient', 'Doctor'], required: true },

  type: { type: String, enum: ['subscription', 'system', 'maintenance', 'test_result'], default: 'subscription' },
  title: String,
  message: String,
  related_id: { type: mongoose.Schema.Types.ObjectId }, 
  is_read: { type: Boolean, default: false },
  created_at: { type: Date, default: Date.now }
});
module.exports = mongoose.model('Notification', NotificationSchema);