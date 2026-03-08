const mongoose = require('mongoose');

const billSchema = new mongoose.Schema({
    readingId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Reading',
        unique: true,
        required: true,
        index: true // Ensuring 1-to-1 relationships for billing to reading
    },
    previousReadingId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Reading',
        default: null
    },
    consumption: {
        type: Number, // Computed from readingValue - previousReadingValue
        default: null
    },
    tariffBands: {
        type: mongoose.Schema.Types.Mixed, // Track how calculation was broken down into tiers
        default: null
    },
    totalAmount: {
        type: Number,
        default: null
    },
    generatedDate: {
        type: Date,
        default: Date.now,
        index: true
    },
    status: {
        type: String,
        enum: ['draft', 'final', 'paid'],
        default: 'draft',
        index: true // Commonly queried to find 'unpaid' bills
    }
});

module.exports = mongoose.model('Bill', billSchema);
