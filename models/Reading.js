const mongoose = require('mongoose');

const readingSchema = new mongoose.Schema({
    meterId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Meter',
        required: true,
        index: true // Helpful for finding all readings for a given meter
    },
    imagePath: {
        type: String,
        default: null
    },
    readingValue: {
        type: Number,
        default: null
    },
    serialNumberExtracted: {
        type: String,
        default: null
    },
    confidence: {
        type: Number,
        default: null
    },
    validationStatus: {
        type: String,
        enum: ['pending', 'validated', 'failed', 'fraud_suspected'],
        default: 'pending',
        index: true // Frequently queried to process 'pending' readings
    },
    submissionTime: {
        type: Date,
        default: Date.now,
        index: true // Sorting readings by time
    },
    billingPeriod: {
        type: String, // e.g., '2023-10'
        default: null
    }
});

module.exports = mongoose.model('Reading', readingSchema);
