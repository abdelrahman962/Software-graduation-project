const mongoose = require('mongoose');

const feedbackSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    refPath: 'user_model'
  },
  user_model: {
    type: String,
    required: true,
    enum: ['Doctor', 'Patient', 'Staff', 'Owner']
  },
  target_type: {
    type: String,
    required: true,
    enum: ['system', 'lab', 'test', 'order', 'service']
  },
  target_id: {
    type: mongoose.Schema.Types.ObjectId,
    required: function() { return this.target_type !== 'system'; },
    refPath: 'target_model'
  },
  target_model: {
    type: String,
    required: function() { return this.target_type !== 'system'; },
    enum: ['Owner', 'Test', 'Order', 'Service']
  },
  rating: {
    type: Number,
    min: 1,
    max: 5,
    required: true
  },
  message: {
    type: String,
    required: true,
    trim: true,
    maxlength: 1000
  },
  is_anonymous: {
    type: Boolean,
    default: false
  },
  is_anonymous: {
    type: Boolean,
    default: false
  },
  status: {
    type: String,
    enum: ['pending', 'reviewed', 'responded'],
    default: 'pending'
  },
  response: {
    message: String,
    responded_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Staff'
    },
    responded_at: Date
  }
}, {
  timestamps: true
});

// Indexes for better query performance
feedbackSchema.index({ user_id: 1, createdAt: -1 });
feedbackSchema.index({ target_id: 1, target_type: 1, createdAt: -1 });
feedbackSchema.index({ target_type: 1, createdAt: -1 });
feedbackSchema.index({ status: 1, createdAt: -1 });
feedbackSchema.index({ rating: 1, createdAt: -1 });

// Virtual for average rating calculation
feedbackSchema.statics.getAverageRating = async function(targetId, targetType) {
  const result = await this.aggregate([
    { $match: { target_id: targetId, target_type: targetType } },
    { $group: { _id: null, average: { $avg: '$rating' }, count: { $sum: 1 } } }
  ]);
  return result.length > 0 ? { average: result[0].average, count: result[0].count } : { average: 0, count: 0 };
};

// Virtual for feedback statistics
feedbackSchema.statics.getFeedbackStats = async function(targetId, targetType) {
  return await this.aggregate([
    { $match: { target_id: targetId, target_type: targetType } },
    {
      $group: {
        _id: '$rating',
        count: { $sum: 1 }
      }
    },
    {
      $sort: { '_id': -1 }
    }
  ]);
};

module.exports = mongoose.model('Feedback', feedbackSchema);