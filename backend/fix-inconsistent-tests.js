require('dotenv').config();
const mongoose = require('mongoose');
const OrderDetails = require('./models/OrderDetails');
const Result = require('./models/Result');
const Test = require('./models/Test');
const Order = require('./models/Order');

const fixInconsistentTests = async () => {
  try {
    console.log('✅ MongoDB Connected\n');
    
    console.log('========================================');
    console.log('FIXING INCONSISTENT TEST STATUS');
    console.log('========================================\n');
    
    // Find all OrderDetails with status 'completed'
    const completedTests = await OrderDetails.find({ status: 'completed' })
      .populate('test_id', 'test_name test_code')
      .populate('order_id', 'barcode');
    
    console.log(`📊 Total Completed Tests Found: ${completedTests.length}\n`);
    
    let fixedCount = 0;
    let alreadyOkCount = 0;
    let errorCount = 0;
    
    for (const detail of completedTests) {
      try {
        // Check if result exists
        const result = await Result.findOne({ detail_id: detail._id });
        
        if (result) {
          console.log(`✓ Test ${detail._id} (${detail.test_id?.test_name || 'Unknown'}) has result - OK`);
          alreadyOkCount++;
          continue;
        }
        
        // No result found - this is the inconsistency
        console.log(`\n⚠️  INCONSISTENCY FOUND:`);
        console.log(`   Test: ${detail.test_id?.test_name || 'Unknown'}`);
        console.log(`   Test Code: ${detail.test_id?.test_code || 'N/A'}`);
        console.log(`   Order: ${detail.order_id?.barcode || 'N/A'}`);
        console.log(`   Status: ${detail.status}`);
        console.log(`   Result: NOT FOUND`);
        
        // Determine appropriate status based on other fields
        let newStatus = 'pending';
        
        if (detail.sample_collected) {
          newStatus = 'collected';
        }
        if (detail.staff_id) {
          newStatus = 'assigned';
        }
        
        console.log(`   Fixing status: completed → ${newStatus}`);
        
        // Update the status
        detail.status = newStatus;
        detail.result_id = null; // Clear any incorrect result_id reference
        await detail.save();
        
        console.log(`   ✅ Fixed!\n`);
        fixedCount++;
        
      } catch (error) {
        console.error(`   ❌ Error fixing test ${detail._id}:`, error.message);
        errorCount++;
      }
    }
    
    console.log('\n========================================');
    console.log('FIX SUMMARY');
    console.log('========================================');
    console.log(`Total Completed Tests: ${completedTests.length}`);
    console.log(`✅ Fixed (status corrected): ${fixedCount}`);
    console.log(`✓  Already OK (has result): ${alreadyOkCount}`);
    console.log(`❌ Errors: ${errorCount}`);
    console.log('\n✅ Fix completed!\n');
    
    if (fixedCount > 0) {
      console.log('💡 Next Steps:');
      console.log('   1. Owner should assign staff to these tests');
      console.log('   2. Staff should collect samples');
      console.log('   3. Staff should perform tests and upload results');
      console.log('   4. Status will be automatically set to "completed" when result is uploaded\n');
    }
    
  } catch (error) {
    console.error('\n❌ Fix error:', error);
  } finally {
    await mongoose.connection.close();
    console.log('👋 Database connection closed. Goodbye!\n');
  }
};

// Connect to MongoDB and run fix
mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    fixInconsistentTests();
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });
