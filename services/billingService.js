const Bill = require('../models/Bill');
const Reading = require('../models/Reading');
const tariffs = require('../config/tariffs');

/**
 * Calculates total bill amount using tiered tariff structure.
 * @param {Number} consumption 
 * @returns {Object} Total amount and the breakdown mapping for auditing.
 */
const calculateAmount = (consumption) => {
    let remaining = consumption;
    let totalAmount = 0;
    let previousLimit = 0;
    const breakdown = [];

    for (const band of tariffs) {
        if (remaining <= 0) break;

        // How many units exist in this specific tier structure
        const bandSize = band.upTo - previousLimit;
        const billableUnitsInBand = Math.min(remaining, bandSize);

        const costForBand = billableUnitsInBand * band.rate;
        totalAmount += costForBand;
        remaining -= billableUnitsInBand;

        breakdown.push({
            units: billableUnitsInBand,
            rate: band.rate,
            cost: costForBand,
            tierName: `Tier ${breakdown.length + 1} (up to ${band.upTo})`
        });

        previousLimit = band.upTo;
    }

    return { totalAmount, breakdown };
};

/**
 * Generates a bill based on a recently validated reading.
 * @param {ObjectId} readingId 
 * @returns {Promise<Object>} The generated Bill document.
 */
exports.generateBill = async (readingId) => {
    try {
        const currentReading = await Reading.findById(readingId);

        if (!currentReading) {
            throw new Error(`Reading ${readingId} not found.`);
        }

        // Ensure we only bill for completed validations
        if (currentReading.validationStatus !== 'validated') {
            throw new Error(`Cannot generate bill for reading ${readingId} with status ${currentReading.validationStatus}.`);
        }

        // Fetch the previous reading to gauge consumption
        const previousReading = await Reading.findOne({
            meterId: currentReading.meterId,
            validationStatus: 'validated',
            submissionTime: { $lt: currentReading.submissionTime }
        }).sort({ submissionTime: -1 });

        const previousReadingValue = previousReading ? previousReading.readingValue : 0;
        const previousReadingId = previousReading ? previousReading._id : null;

        // Calculate flat consumption
        const consumption = currentReading.readingValue - previousReadingValue;

        // Safety check: Cannot be negative here since validationService should have caught this.
        // If we land here somehow, default to 0 to prevent paying users
        const actualConsumption = consumption < 0 ? 0 : consumption;

        // Calculate monetary pricing tiers
        const { totalAmount, breakdown } = calculateAmount(actualConsumption);

        // Form bill mapping
        const bill = new Bill({
            readingId: currentReading._id,
            previousReadingId: previousReadingId,
            consumption: actualConsumption,
            tariffBands: breakdown,
            totalAmount: totalAmount,
            status: 'final' // Per instructions, immediately solidify bill
        });

        const savedBill = await bill.save();
        console.log(`[Billing Service] Generated Bill ${savedBill._id} for reading ${readingId}. Total: $${totalAmount}`);

        return savedBill;

    } catch (error) {
        console.error(`[Billing Service] Error generating bill for reading ${readingId}:`, error);
        throw error;
    }
};
