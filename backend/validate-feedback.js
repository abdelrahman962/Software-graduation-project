const mongoose = require('mongoose');
const Feedback = require('./models/Feedback');

async function validateFeedbackSystem() {
  try {
    console.log('🔍 Validating Feedback System...');

    // Connect to database (will use test connection if available)
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/medical_lab_system';
    await mongoose.connect(mongoUri);
    console.log('✅ Database connected');

    // Test 1: Create feedback instance
    const testFeedback = new Feedback({
      user_id: new mongoose.Types.ObjectId(),
      user_model: 'Patient',
      target_type: 'lab',
      target_id: new mongoose.Types.ObjectId(),
      rating: 5,
      message: 'Excellent service!',
      is_anonymous: false
    });

    console.log('✅ Feedback model instantiated successfully');

    // Test 2: Validate schema
    await testFeedback.validate();
    console.log('✅ Feedback validation passed');

    // Test 3: Check static methods exist
    if (typeof Feedback.getAverageRating === 'function') {
      console.log('✅ getAverageRating method exists');
    } else {
      console.log('❌ getAverageRating method missing');
    }

    if (typeof Feedback.getFeedbackStats === 'function') {
      console.log('✅ getFeedbackStats method exists');
    } else {
      console.log('❌ getFeedbackStats method missing');
    }

    // Test 4: Check virtuals
    if (testFeedback.user) {
      console.log('✅ User virtual exists');
    } else {
      console.log('❌ User virtual missing');
    }

    if (testFeedback.target) {
      console.log('✅ Target virtual exists');
    } else {
      console.log('❌ Target virtual missing');
    }

    console.log('🎉 Feedback system validation completed successfully!');

  } catch (error) {
    console.error('❌ Validation failed:', error.message);
    process.exit(1);
  } finally {
    await mongoose.connection.close();
  }
}

// Run validation if this script is executed directly
if (require.main === module) {
  validateFeedbackSystem();
}

module.exports = validateFeedbackSystem;