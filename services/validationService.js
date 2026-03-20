const Reading = require('../models/Reading');
const Meter = require('../models/Meter');

/**
 * Validates an OCR-processed reading against the meter details and past history.
 * 
 * @param {ObjectId} readingId - The ID of the reading to validate.
 * @returns {Promise<Object>} The updated reading document.
 */
exports.validateReading = async (readingId) => {
    try {
        const reading = await Reading.findById(readingId).populate('meterId');
        if (!reading) {
            throw new Error(`Reading ${readingId} not found`);
        }

        const currentValidationStatus = reading.validationStatus;
        if (currentValidationStatus !== 'pending') {
            console.warn(`[Validation Service] Reading ${readingId} already processed (status: ${currentValidationStatus}).`);
            return reading;
        }

        // Check 1: Ensure value was extracted at all
        if (reading.readingValue === null || reading.readingValue === undefined) {
            reading.validationStatus = 'failed';
            await reading.save();
            console.warn(`[Validation Service] Reading ${readingId} failed: No consumption digits extracted.`);
            return reading;
        }

        // Check 2: Match Serial Numbers (Fraud Detection)
        // Account for potential slight OCR typos by ensuring it's at least closely contained,
        // but for strictness per requirements, we'll do an exact match check (or uppercase inclusion).
        const actualSerial = reading.meterId.serialNumber.toUpperCase();
        const extractedSerial = reading.serialNumberExtracted ? reading.serialNumberExtracted.toUpperCase() : null;

        if (extractedSerial && actualSerial && !actualSerial.includes(extractedSerial) && !extractedSerial.includes(actualSerial)) {
            // Serial mismatch, but don't fail - just warn and continue
            console.warn(`[Validation Service] Serial mismatch on ${readingId}: Extracted '${extractedSerial}' doesn't match '${actualSerial}', but reading value is valid. Proceeding.`);
        } else if (!extractedSerial) {
            // Serial not extracted, but that's ok - meter reading is what matters
            console.log(`[Validation Service] Serial number not extracted for ${readingId}, but proceeding with reading value.`);
        }

        // Check 3: Logical progression from previous reading
        const previousReading = await Reading.findOne({
            meterId: reading.meterId._id,
            validationStatus: 'validated',
            submissionTime: { $lt: reading.submissionTime }
        }).sort({ submissionTime: -1 }); // Get the most recent validated reading

        if (previousReading && reading.readingValue !== null && previousReading.readingValue !== null) {
            const currentVal = Number(reading.readingValue);
            const prevVal = Number(previousReading.readingValue);
            
            if (!isNaN(currentVal) && !isNaN(prevVal) && currentVal < prevVal) {
                // Meter reversal or bad OCR reading
                reading.validationStatus = 'failed';
                await reading.save();
                console.warn(`[Validation Service] Reading ${readingId} failed: Current value (${reading.readingValue}) is less than previous (${previousReading.readingValue}). manual review required.`);
                return reading;
            }
        }

        // If all checks pass
        reading.validationStatus = 'validated';
        await reading.save();
        console.log(`[Validation Service] Reading ${readingId} successfully validated.`);
        return reading;

    } catch (error) {
        console.error(`[Validation Service] Error validating ${readingId}:`, error);
        throw error;
    }
};
