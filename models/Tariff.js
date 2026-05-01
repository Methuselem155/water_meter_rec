const mongoose = require('mongoose');

const bandSchema = new mongoose.Schema({
    upTo: { type: Number, required: true },
    rate: { type: Number, required: true },
}, { _id: false });

const tariffSchema = new mongoose.Schema({
    category: {
        type: String,
        required: true,
        unique: true,
        enum: ['PUBLIC TAP', 'RESIDENTIAL', 'NON RESIDENTIAL', 'INDUSTRIES'],
    },
    type: {
        type: String,
        required: true,
        enum: ['flat', 'progressive'],
    },
    rate: { type: Number },
    bands: [bandSchema],
    vatRate: { type: Number, required: true, default: 0.18 },
}, { timestamps: true });

module.exports = mongoose.model('Tariff', tariffSchema);
