const mongoose = require('mongoose');
require('dotenv').config();

async function clearDatabase() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/water-meter';
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    // Clear readings collection
    const readingsResult = await mongoose.connection.collection('readings').deleteMany({});
    console.log(`✅ Deleted ${readingsResult.deletedCount} readings`);

    // Clear bills collection
    const billsResult = await mongoose.connection.collection('bills').deleteMany({});
    console.log(`✅ Deleted ${billsResult.deletedCount} bills`);

    // Clear users collection (optional - only methuselem account)
    // const usersResult = await mongoose.connection.collection('users').deleteMany({ username: 'methuselem' });
    // console.log(`✅ Deleted ${usersResult.deletedCount} user records`);

    console.log('✅ Database cleared successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error clearing database:', error.message);
    process.exit(1);
  }
}

clearDatabase();
