const mongoose = require('mongoose');

const billSchema = new mongoose.Schema({
    readingId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Reading',
        unique: true,
        required: true,
        index: true
    },
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
        index: true
    },
    previousReadingId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Reading',
        default: null
    },
    previousReadingValue: {
        type: Number,
        default: null
    },
    currentReadingValue: {
        type: Number,
        default: null
    },
    consumption: {
        type: Number,
        default: null
    },
    category: {
        type: String,
        enum: ['PUBLIC TAP', 'RESIDENTIAL', 'NON RESIDENTIAL', 'INDUSTRIES'],
        default: null
    },
    tariffBands: {
        type: mongoose.Schema.Types.Mixed,
        default: null
    },
    totalAmount: {
        type: Number,
        default: null
    },
    vatAmount: {
        type: Number,
        default: null
    },
    totalAmountVatInclusive: {
        type: Number,
        default: null
    },
    generatedDate: {
        type: Date,
        default: Date.now,
        index: true
    },
    dueDate: {
        type: Date,
        default: null,
        index: true
    },
    status: {
        type: String,
        enum: ['unpaid', 'paid', 'overdue'],
        default: 'unpaid',
        index: true
    },
    paidAt: {
        type: Date,
        default: null
    },
    paymentReference: {
        type: String,
        default: null
    },
    paymentMethod: {
        type: String,
        enum: ['momo', 'bank', 'cash'],
        default: null
    }
});

module.exports = mongoose.model('Bill', billSchema);
