const Bill = require('../models/Bill');
const Reading = require('../models/Reading');
const Meter = require('../models/Meter');
const User = require('../models/User');
const { TARIFFS, VAT_RATE } = require('../config/tariffs');

/**
 * Calculate bill amount for a given category and consumption.
 * Returns totalAmount (VAT exclusive), breakdown, vatAmount, totalAmountVatInclusive.
 *
 * @param {string} category - Customer category
 * @param {number} consumption - m³ consumed
 * @returns {{ totalAmount, breakdown, vatAmount, totalAmountVatInclusive }}
 */
const calculateBill = (category, consumption) => {
    const tariff = TARIFFS[category];
    if (!tariff) throw new Error(`Unknown tariff category: ${category}`);

    let totalAmount = 0;
    let breakdown = [];

    if (tariff.type === 'flat') {
        totalAmount = consumption * tariff.rate;
        breakdown = [{
            units: consumption,
            rate: tariff.rate,
            cost: totalAmount,
            tierName: 'Flat rate',
        }];
    } else {
        // Progressive / block calculation
        let remaining = consumption;
        let previousLimit = 0;

        for (const band of tariff.bands) {
            if (remaining <= 0) break;

            const bandSize = band.upTo === Infinity
                ? remaining
                : band.upTo - previousLimit;

            const billableUnits = Math.min(remaining, bandSize);
            const cost = billableUnits * band.rate;

            totalAmount += cost;
            remaining -= billableUnits;

            breakdown.push({
                units: billableUnits,
                rate: band.rate,
                cost,
                tierName: band.upTo === Infinity
                    ? `Above ${previousLimit} m³`
                    : `${previousLimit + 1}–${band.upTo} m³`,
            });

            previousLimit = band.upTo;
        }
    }

    const vatAmount = Math.round(totalAmount * VAT_RATE * 100) / 100;
    const totalAmountVatInclusive = Math.round((totalAmount + vatAmount) * 100) / 100;
    totalAmount = Math.round(totalAmount * 100) / 100;

    return { totalAmount, breakdown, vatAmount, totalAmountVatInclusive };
};

/**
 * Generate a bill for a validated reading.
 * Fetches user category, computes consumption, applies tariff.
 *
 * @param {ObjectId} readingId
 * @returns {Promise<Bill>}
 */
exports.generateBill = async (readingId) => {
    try {
        const currentReading = await Reading.findById(readingId).populate('meterId');
        if (!currentReading) throw new Error(`Reading ${readingId} not found.`);

        if (currentReading.validationStatus !== 'validated') {
            throw new Error(`Cannot bill reading ${readingId} with status ${currentReading.validationStatus}.`);
        }

        // Fetch user via meter
        const meter = currentReading.meterId;
        const user = await User.findById(meter.userId).select('category');
        if (!user) throw new Error(`User not found for meter ${meter._id}`);

        const category = user.category || 'RESIDENTIAL';

        // Fetch previous validated reading for this meter
        const previousReading = await Reading.findOne({
            meterId: currentReading.meterId._id || currentReading.meterId,
            validationStatus: 'validated',
            submissionTime: { $lt: currentReading.submissionTime },
        }).sort({ submissionTime: -1 });

        const previousReadingValue = previousReading ? previousReading.readingValue : null;
        const previousReadingId = previousReading ? previousReading._id : null;

        // First reading — no previous, no bill yet
        if (previousReadingValue === null) {
            console.log(`[Billing] First reading for meter ${meter._id} — no bill generated.`);
            return null;
        }

        const consumption = currentReading.readingValue - previousReadingValue;

        if (consumption < 0) {
            throw new Error(
                `Negative consumption for reading ${readingId}: ` +
                `current=${currentReading.readingValue}, previous=${previousReadingValue}.`
            );
        }

        const { totalAmount, breakdown, vatAmount, totalAmountVatInclusive } =
            calculateBill(category, consumption);

        const bill = new Bill({
            readingId: currentReading._id,
            userId: user._id,
            previousReadingId,
            previousReadingValue,
            currentReadingValue: currentReading.readingValue,
            consumption,
            category,
            tariffBands: breakdown,
            totalAmount,
            vatAmount,
            totalAmountVatInclusive,
            status: 'unpaid',
            dueDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        });

        const saved = await bill.save();
        console.log(
            `[Billing] Bill ${saved._id} — category=${category} ` +
            `consumption=${consumption}m³ amount=${totalAmount} RWF (VAT incl: ${totalAmountVatInclusive})`
        );

        return saved;

    } catch (error) {
        console.error(`[Billing] Error generating bill for reading ${readingId}:`, error.message);
        throw error;
    }
};

// Export for testing / direct use
exports.calculateBill = calculateBill;
