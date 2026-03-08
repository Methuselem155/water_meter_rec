const Reading = require('../models/Reading');
const Meter = require('../models/Meter');
const ocrService = require('../services/ocrService');
const validationService = require('../services/validationService');
const billingService = require('../services/billingService');

/**
 * Process a water meter reading image in the background.
 * Updates the associated Reading document with extracted results.
 * 
 * @param {ObjectId} readingId - The MongoDB ID of the reading to process
 */
const runOcrJob = async (readingId) => {
    console.log(`[OCR Worker] Starting job for reading ID: ${readingId}`);

    try {
        // 1. Retrieve the reading from DB
        const reading = await Reading.findById(readingId).populate('meterId');
        if (!reading) {
            console.error(`[OCR Worker] Reading ${readingId} not found in DB.`);
            return;
        }

        if (reading.validationStatus !== 'pending') {
            console.log(`[OCR Worker] Reading ${readingId} is not in pending state. Skipping.`);
            return;
        }

        // 2. Process image using our service
        if (!reading.imagePath) {
            throw new Error('Reading does not contain a valid imagePath');
        }

        const ocrResult = await ocrService.processImage(reading.imagePath);
        console.log(`[OCR Worker] OCR Success for ${readingId}. Extracted Value: ${ocrResult.readingValue}, Serial: ${ocrResult.serialNumberExtracted}, Confidence: ${parseFloat(ocrResult.confidence).toFixed(2)}%`);

        // 3. Update the reading document with values
        reading.readingValue = ocrResult.readingValue;
        reading.serialNumberExtracted = ocrResult.serialNumberExtracted;
        reading.confidence = ocrResult.confidence;

        // We leave validationStatus as 'pending' here, because next step is the validationService
        // which checks if readingValue > previousReadingValue, maps serial to db, etc.
        await reading.save();
        console.log(`[OCR Worker] Job completed and saved for reading ID: ${readingId}`);

        // Trigger validation and billing pipeline safely
        const validatedReading = await validationService.validateReading(readingId);

        // Only bill if OCR explicitly verified reading was logically sound
        if (validatedReading.validationStatus === 'validated') {
            await billingService.generateBill(readingId);
        }

    } catch (error) {
        console.error(`[OCR Worker] Job failed for reading ID: ${readingId}`, error);

        // 4. On failure, mark the reading as failed for manual review
        // We intentionally ignore errors trying to write the failure state to prevent crash looping
        try {
            await Reading.findByIdAndUpdate(readingId, {
                validationStatus: 'failed',
                confidence: 0
            });
        } catch (saveError) {
            console.error('[OCR Worker] Could not update reading failure status', saveError);
        }
    }
};

module.exports = { runOcrJob };
