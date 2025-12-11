require('dotenv').config();
const mongoose = require('mongoose');
const Result = require('./models/Result');
const OrderDetails = require('./models/OrderDetails');
const Test = require('./models/Test');

const migrateResults = async () => {
  try {
    console.log('✅ MongoDB Connected\n');
    
    console.log('========================================');
    console.log('MIGRATING OLD RESULT DOCUMENTS');
    console.log('========================================\n');
    
    // Find all results
    const results = await Result.find({});
    
    console.log(`📊 Total Results Found: ${results.length}\n`);
    
    if (results.length === 0) {
      console.log('⚠️  No results found in the database');
      return;
    }
    
    let updatedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;
    
    for (const result of results) {
      try {
        // Check if this result needs migration
        const needsMigration = 
          !result.units || 
          !result.reference_range || 
          !result.createdAt || 
          !result.updatedAt;
        
        if (!needsMigration) {
          console.log(`✓ Result ${result._id} already up to date`);
          skippedCount++;
          continue;
        }
        
        console.log(`\n🔄 Migrating Result ${result._id}...`);
        
        // Get the associated OrderDetails with test information
        const detail = await OrderDetails.findById(result.detail_id)
          .populate('test_id', 'units reference_range');
        
        if (!detail) {
          console.log(`  ⚠️  OrderDetail not found for result ${result._id}`);
          errorCount++;
          continue;
        }
        
        if (!detail.test_id) {
          console.log(`  ⚠️  Test not found for result ${result._id}`);
          errorCount++;
          continue;
        }
        
        const test = detail.test_id;
        
        // Update the result with missing fields
        const updateFields = {};
        
        if (!result.units && test.units) {
          updateFields.units = test.units;
          console.log(`  + Adding units: ${test.units}`);
        }
        
        if (!result.reference_range && test.reference_range) {
          updateFields.reference_range = test.reference_range;
          console.log(`  + Adding reference_range: ${test.reference_range}`);
        }
        
        // Add timestamps if missing (use current date as fallback)
        if (!result.createdAt) {
          updateFields.createdAt = result._id.getTimestamp(); // Extract from MongoDB ObjectId
          console.log(`  + Adding createdAt: ${updateFields.createdAt}`);
        }
        
        if (!result.updatedAt) {
          updateFields.updatedAt = result._id.getTimestamp();
          console.log(`  + Adding updatedAt: ${updateFields.updatedAt}`);
        }
        
        // Update the document
        if (Object.keys(updateFields).length > 0) {
          await Result.updateOne(
            { _id: result._id },
            { $set: updateFields }
          );
          console.log(`  ✅ Successfully migrated Result ${result._id}`);
          updatedCount++;
        } else {
          console.log(`  ℹ️  No fields to update for Result ${result._id}`);
          skippedCount++;
        }
        
      } catch (error) {
        console.error(`  ❌ Error migrating Result ${result._id}:`, error.message);
        errorCount++;
      }
    }
    
    console.log('\n========================================');
    console.log('MIGRATION SUMMARY');
    console.log('========================================');
    console.log(`Total Results: ${results.length}`);
    console.log(`✅ Updated: ${updatedCount}`);
    console.log(`⏭️  Skipped (already up to date): ${skippedCount}`);
    console.log(`❌ Errors: ${errorCount}`);
    console.log('\n✅ Migration completed!\n');
    
  } catch (error) {
    console.error('\n❌ Migration error:', error);
  } finally {
    await mongoose.connection.close();
    console.log('👋 Database connection closed. Goodbye!\n');
  }
};

// Connect to MongoDB and run migration
mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    migrateResults();
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });
