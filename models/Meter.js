const mongoose = require('mongoose');

const meterSchema = new mongoose.Schema({
    serialNumber: {
        type: String,
        unique: true,
        required: true,
        index: true // Keep track of the physical meter uniquely
    },
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true // Important for querying meters belonging to a specific user
    },
    installationDate: {
        type: Date,
        default: null
    },
    status: {
        type: String,
        enum: ['active', 'inactive', 'decommissioned'],
        default: 'active'
    }
});

module.exports = mongoose.model('Meter', meterSchema);
