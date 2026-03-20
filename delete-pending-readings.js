#!/usr/bin/env node
/**
 * Delete all pending readings from the database
 * Usage: node delete-pending-readings.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Reading = require('./models/Reading');

const connectDB = async () => {
    try {
        const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/water-meter';
        await mongoose.connect(uri);
        console.log('Connected to MongoDB');
    } catch (error) {
        console.error('Error connecting to MongoDB:', error.message);
        process.exit(1);
    }
};

const deleteAllPendingReadings = async () => {
    try {
        console.log('\n========================================');
        console.log('DELETING PENDING READINGS');
        console.log('========================================\n');

        // Delete all readings with validationStatus = 'pending'
        const result = await Reading.deleteMany({ validationStatus: 'pending' });

        console.log(`✓ Deleted ${result.deletedCount} pending readings from database`);

        // Also delete any readings at all (fresh start)
        const allReadings = await Reading.deleteMany({});
        console.log(`✓ Deleted all readings (total cleaned): ${allReadings.deletedCount}`);

        console.log('\n✓ Database cleanup complete!\n');
        process.exit(0);
    } catch (error) {
        console.error('Error deleting readings:', error.message);
        process.exit(1);
    }
};

const main = async () => {
    await connectDB();
    await deleteAllPendingReadings();
};

main();
