const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    accountNumber: {
        type: String,
        unique: true,
        required: true,
        index: true // Index for fast lookup by account number
    },
    fullName: {
        type: String,
        required: true
    },
    phoneNumber: {
        type: String,
        unique: true,
        required: true,
        index: true // Index for fast lookup/login by phone
    },
    email: {
        type: String,
        default: null
    },
    category: {
        type: String,
        enum: ['PUBLIC TAP', 'RESIDENTIAL', 'NON RESIDENTIAL', 'INDUSTRIES'],
        required: true,
        default: 'RESIDENTIAL'
    },
    role: {
        type: String,
        enum: ['user', 'admin'],
        default: 'user'
    },
    passwordHash: {
        type: String,
        required: true
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

// Ensure indexes are created, applying 'unique' contraints
module.exports = mongoose.model('User', userSchema);
