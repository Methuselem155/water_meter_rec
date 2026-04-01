const Reading = require('../models/Reading');
const ocrService = require('../services/ocrService');
const validationService = require('../services/validationService');
const billingService = require('../services/billingService');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');
const os = require('os');

/**
 * Resolve imagePath to a local file path.
 * If it's a Cloudinary/HTTP URL, download to a temp file first.
 * Returns { localPath, isTemp }.
 */
const resolveImagePath = (imagePath) => {
    return new Promise((resolve, reject) => {
        if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
            const ext = path.extname(new URL(imagePath).pathname) || '.jpg';
            const tmpFile = path.join(os.tmpdir(), `ocr_${Date.now()}${ext}`);
            const file = fs.createWriteStream(tmpFile);
            const client = imagePath.startsWith('https://') ? https : http;
            client.get(imagePath, (res) => {
                res.pipe(file);
                file.on('finish', () => file.close(() => resolve({ localPath: tmpFile, isTemp: true })));
            }).on('error', (err) => {
                fs.unlink(tmpFile, () => {});
                reject(err);
            });
        } else {
            const localPath = path.isAbsolute(imagePath)
                ? imagePath
                : path.join(__dirname, '..', imagePath);
            resolve({ localPath, isTemp: false });
        }
    });
};

/**
 * Run OCR on a reading, then validate and bill if successful.
 * @param {ObjectId} readingId
 */
const runOcrJob = async (readingId) => {
    console.log(`[OCR Worker] Starting job for reading: ${readingId}`);

    let absolutePath = null;
    let isTemp = false;

    try {
        const reading = await Reading.findById(readingId).populate('meterId');
        if (!reading) {
            console.error(`[OCR Worker] Reading ${readingId} not found`);
            return;
        }

        if (reading.validationStatus !== 'pending') {
            console.log(`[OCR Worker] Reading ${readingId} already processed (${reading.validationStatus}), skipping`);
            return;
        }

        if (!reading.imagePath) {
            throw new Error('Reading has no imagePath');
        }

        // Resolve to local path (download from Cloudinary if needed)
        const resolved = await resolveImagePath(reading.imagePath);
        absolutePath = resolved.localPath;
        isTemp = resolved.isTemp;

        console.log(`[OCR Worker] Running OCR on: ${absolutePath}`);
        const ocrResult = await ocrService.processImage(absolutePath);

        console.log(`[OCR Worker] OCR done — value=${ocrResult.readingValue} serial=${ocrResult.serialNumberExtracted} conf=${ocrResult.confidence}`);

        // Save OCR results
        reading.readingValue = ocrResult.readingValue;
        reading.serialNumberExtracted = ocrResult.serialNumberExtracted;
        reading.confidence = ocrResult.confidence;
        reading.ocrRawText = ocrResult.rawText || null;
        reading.ocrMethod = ocrResult.ocrMethod;
        await reading.save();

        // Validate then bill
        const validated = await validationService.validateReading(readingId);
        if (validated.validationStatus === 'validated') {
            await billingService.generateBill(readingId);
        }

    } catch (error) {
        console.error(`[OCR Worker] Job failed for ${readingId}:`, error.message);
        await Reading.findByIdAndUpdate(readingId, {
            validationStatus: 'failed',
            confidence: 0,
            ocrMethod: 'failed',
        }).catch(() => {});
    } finally {
        // Always clean up temp file
        if (isTemp && absolutePath) {
            fs.unlink(absolutePath, () => {});
        }
    }
};

module.exports = { runOcrJob, resolveImagePath };
