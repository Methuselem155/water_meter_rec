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
    ocrRawText: {
        type: String,
        default: null
    },
    ocrMethod: {
        type: String,
        enum: ['python-tesseract', 'easyocr', 'easyocr-crop', 'tesseract-fallback', 'tesseract.js', 'manual', 'failed', null],
        default: null,
        description: 'Which OCR method was used to extract the reading'
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
    },
    // OCR retry tracking
    ocrRetryCount: {
        type: Number,
        default: 0,
        min: 0,
        max: 5
    },
    lastOcrError: {
        type: String,
        default: null
    },
    lastOcrAttempt: {
        type: Date,
        default: null
    }
});

module.exports = mongoose.model('Reading', readingSchema);
