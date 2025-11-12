require('dotenv').config();
const mongoose = require('mongoose');
const LabOwner = require('./models/Owner');
const Staff = require('./models/Staff');
const Patient = require('./models/Patient');
const Admin = require('./models/Admin');

async function normalizeUsernames() {
  try {
    console.log('🔄 Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connected to MongoDB\n');

    // Normalize Owner usernames
    console.log('📋 Normalizing Lab Owner usernames...');
    const owners = await LabOwner.find({});
    for (const owner of owners) {
      const oldUsername = owner.username;
      const newUsername = oldUsername.replace(/\s+/g, '.').toLowerCase().trim();
      
      if (oldUsername !== newUsername) {
        owner.username = newUsername;
        await owner.save();
        console.log(`✅ Owner: "${oldUsername}" → "${newUsername}"`);
      } else {
        console.log(`✓ Owner: "${oldUsername}" already normalized`);
      }
    }

    // Normalize Staff usernames
    console.log('\n📋 Normalizing Staff usernames...');
    const staffMembers = await Staff.find({});
    for (const staff of staffMembers) {
      const oldUsername = staff.username;
      const newUsername = oldUsername.replace(/\s+/g, '.').toLowerCase().trim();
      
      if (oldUsername !== newUsername) {
        staff.username = newUsername;
        await staff.save();
        console.log(`✅ Staff: "${oldUsername}" → "${newUsername}"`);
      } else {
        console.log(`✓ Staff: "${oldUsername}" already normalized`);
      }
    }

    // Normalize Patient usernames
    console.log('\n📋 Normalizing Patient usernames...');
    const patients = await Patient.find({});
    for (const patient of patients) {
      if (patient.username) {
        const oldUsername = patient.username;
        const newUsername = oldUsername.replace(/\s+/g, '.').toLowerCase().trim();
        
        if (oldUsername !== newUsername) {
          patient.username = newUsername;
          await patient.save();
          console.log(`✅ Patient: "${oldUsername}" → "${newUsername}"`);
        } else {
          console.log(`✓ Patient: "${oldUsername}" already normalized`);
        }
      }
    }

    // Normalize Admin usernames
    console.log('\n📋 Normalizing Admin usernames...');
    const admins = await Admin.find({});
    for (const admin of admins) {
      if (admin.username) {
        const oldUsername = admin.username;
        const newUsername = oldUsername.replace(/\s+/g, '.').toLowerCase().trim();
        
        if (oldUsername !== newUsername) {
          admin.username = newUsername;
          await admin.save();
          console.log(`✅ Admin: "${oldUsername}" → "${newUsername}"`);
        } else {
          console.log(`✓ Admin: "${oldUsername}" already normalized`);
        }
      }
    }

    console.log('\n✅ Username normalization completed!');
    console.log('\n📝 Summary:');
    console.log(`   - Owners processed: ${owners.length}`);
    console.log(`   - Staff processed: ${staffMembers.length}`);
    console.log(`   - Patients processed: ${patients.length}`);
    console.log(`   - Admins processed: ${admins.length}`);
    
    console.log('\n🎯 New Login Format:');
    console.log('   - "Motaz Qarmash" → "motaz.qarmash"');
    console.log('   - "Sara Mohammed" → "sara.mohammed"');
    console.log('   - All spaces replaced with dots');
    console.log('   - All converted to lowercase\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

normalizeUsernames();
