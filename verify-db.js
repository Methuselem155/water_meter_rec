#!/usr/bin/env node
/**
 * Database verification script to check if readings are being saved
 * Usage: node verify-db.js
 */

const mongoose = require('mongoose');
const Reading = require('./models/Reading');
const Meter = require('./models/Meter');
const User = require('./models/User');

const connectDB = async () => {
    try {
        const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/water-meter';
        await mongoose.connect(uri);
        console.log(`✓ Connected to MongoDB: ${uri}`);
    } catch (error) {
        console.error('✗ Failed to connect to MongoDB:', error.message);
        process.exit(1);
    }
};

const verifyData = async () => {
    try {
        console.log('\n========================================');
        console.log('DATABASE VERIFICATION');
        console.log('========================================\n');

        // Check users
        const userCount = await User.countDocuments({});
        console.log(`[Users] Total: ${userCount}`);
        
        if (userCount > 0) {
            const user = await User.findOne({});
            console.log(`  - Sample user: ${user._id} (${user.phoneNumber})`);
        }

        // Check meters
        const meterCount = await Meter.countDocuments({});
        console.log(`\n[Meters] Total: ${meterCount}`);
        
        if (meterCount > 0) {
            const meters = await Meter.find({}).limit(3);
            meters.forEach(m => {
                console.log(`  - Meter: ${m._id} (Serial: ${m.serialNumber}, User: ${m.userId})`);
            });
        }

        // Check readings
        const readingCount = await Reading.countDocuments({});
        console.log(`\n[Readings] Total: ${readingCount}`);

        if (readingCount > 0) {
            const readings = await Reading.find({})
                .sort({ submissionTime: -1 })
                .limit(5)
                .populate('meterId', 'serialNumber userId');

            console.log(`\n  Latest 5 readings:`);
            readings.forEach((r, i) => {
                const date = new Date(r.submissionTime).toLocaleString();
                console.log(`  ${i + 1}. ID: ${r._id}`);
                console.log(`     ├─ Status: ${r.validationStatus}`);
                console.log(`     ├─ ImagePath: ${r.imagePath?.substring(0, 50)}...`);
                console.log(`     ├─ Value: ${r.readingValue || 'NULL'}`);
                console.log(`     ├─ Serial: ${r.serialNumberExtracted || 'NULL'}`);
                console.log(`     ├─ Confidence: ${r.confidence || 'NULL'}`);
                console.log(`     └─ Submitted: ${date}`);
            });
        }

        console.log('\n========================================\n');

    } catch (error) {
        console.error('✗ Error during verification:', error);
    }
};

const main = async () => {
    await connectDB();
    await verifyData();
    await mongoose.disconnect();
    console.log('✓ Disconnected from MongoDB\n');
};

main().catch(err => {
    console.error('✗ Fatal error:', err);
    process.exit(1);
});
