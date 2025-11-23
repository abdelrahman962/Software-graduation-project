const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

// Connect to database
mongoose.connect(process.env.MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

const db = mongoose.connection;

db.on('error', console.error.bind(console, 'MongoDB connection error:'));
db.once('open', async () => {
  console.log('✅ Connected to MongoDB');
  
  try {
    // Migrate Patient addresses
    const patients = await db.collection('patients').find({ address: { $type: 'string' } }).toArray();
    console.log(`\nFound ${patients.length} patients with old address format`);
    
    for (const patient of patients) {
      const newAddress = {
        full_address: patient.address,
        street: patient.address,
        city: '',
        state: '',
        zip_code: '',
        country: 'Palestine',
        coordinates: {
          latitude: null,
          longitude: null
        }
      };
      
      await db.collection('patients').updateOne(
        { _id: patient._id },
        { $set: { address: newAddress } }
      );
    }
    console.log('✅ Migrated patients addresses');
    
    // Migrate Owner addresses
    const owners = await db.collection('labowners').find({ address: { $type: 'string' } }).toArray();
    console.log(`\nFound ${owners.length} owners with old address format`);
    
    for (const owner of owners) {
      const newAddress = {
        full_address: owner.address,
        street: owner.address,
        city: '',
        state: '',
        zip_code: '',
        country: 'Palestine',
        coordinates: {
          latitude: null,
          longitude: null
        }
      };
      
      await db.collection('labowners').updateOne(
        { _id: owner._id },
        { $set: { address: newAddress } }
      );
    }
    console.log('✅ Migrated owners addresses');
    
    // Migrate Staff addresses
    const staff = await db.collection('staff').find({ address: { $type: 'string' } }).toArray();
    console.log(`\nFound ${staff.length} staff with old address format`);
    
    for (const s of staff) {
      const newAddress = {
        full_address: s.address,
        street: s.address,
        city: '',
        state: '',
        zip_code: '',
        country: 'Palestine',
        coordinates: {
          latitude: null,
          longitude: null
        }
      };
      
      await db.collection('staff').updateOne(
        { _id: s._id },
        { $set: { address: newAddress } }
      );
    }
    console.log('✅ Migrated staff addresses');
    
    // Migrate Order addresses
    const orders = await db.collection('orders').find({ address: { $type: 'string' } }).toArray();
    console.log(`\nFound ${orders.length} orders with old address format`);
    
    for (const order of orders) {
      const newAddress = {
        full_address: order.address,
        street: order.address,
        city: '',
        state: '',
        zip_code: '',
        country: 'Palestine',
        coordinates: {
          latitude: null,
          longitude: null
        }
      };
      
      await db.collection('orders').updateOne(
        { _id: order._id },
        { $set: { address: newAddress } }
      );
    }
    console.log('✅ Migrated orders addresses');
    
    // Update LabBranch location.address to location.street
    const branches = await db.collection('labbranches').find({ 'location.address': { $exists: true } }).toArray();
    console.log(`\nFound ${branches.length} branches with old location.address format`);
    
    for (const branch of branches) {
      await db.collection('labbranches').updateOne(
        { _id: branch._id },
        { 
          $set: { 
            'location.street': branch.location.address,
            'location.full_address': branch.location.address 
          },
          $unset: { 'location.address': '' }
        }
      );
    }
    console.log('✅ Migrated branches location.address to location.street');
    
    console.log('\n✅ All migrations completed successfully!');
    
  } catch (error) {
    console.error('❌ Migration error:', error);
  } finally {
    await mongoose.connection.close();
    console.log('\n🔌 Database connection closed');
    process.exit(0);
  }
});
