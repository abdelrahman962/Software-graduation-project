require('dotenv').config();
const mongoose = require('mongoose');
const Result = require('./models/Result');

const fetchAllResults = async () => {
  try {
    console.log('✅ MongoDB Connected\n');
    
    console.log('========================================');
    console.log('RAW RESULTS FROM DATABASE');
    console.log('========================================\n');
    
    // Fetch all results WITHOUT population - just raw data
    const results = await Result.find({}).sort({ createdAt: -1 });
    
    console.log(`📊 Total Results Found: ${results.length}\n`);
    
    if (results.length === 0) {
      console.log('⚠️  No results found in the database');
      return;
    }
    
    // Print raw JSON data
    console.log('RAW DATA FROM RESULTS COLLECTION:\n');
    console.log(JSON.stringify(results, null, 2));
    
    console.log('\n========================================');
    console.log('SUMMARY');
    console.log('========================================');
    console.log(`Total Results: ${results.length}\n`);
    
  } catch (error) {
    console.error('\n❌ Error fetching results:', error);
  } finally {
    await mongoose.connection.close();
    console.log('👋 Database connection closed. Goodbye!\n');
  }
};

// Connect to MongoDB and fetch results
mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    fetchAllResults();
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });
