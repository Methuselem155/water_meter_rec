const sharp = require('sharp');
const Tesseract = require('tesseract.js');
const fs = require('fs');
const path = require('path');

/**
 * Preprocess the image using sharp to improve OCR accuracy.
 * Converts to grayscale, applies a simple threshold, and resizes.
 * 
 * @param {string} imagePath - Absolute path to the uploaded image.
 * @returns {Promise<Buffer>} - Resizes image buffer.
 */
const preprocessImage = async (imagePath) => {
    try {
        return await sharp(imagePath)
            .resize(1200, null, { // Resize to 1200px width, preserving aspect ratio
                fit: sharp.fit.inside,
                withoutEnlargement: true
            })
            .grayscale() // Convert to grayscale
            .normalize() // Enhance contrast
            .threshold(128) // Simple binarization (pixels > 128 become white, else black)
            .toBuffer();
    } catch (error) {
        console.error('Error preprocessing image:', error);
        throw new Error('Image preprocessing failed');
    }
};

/**
 * Parses the raw Tesseract string looking for numeric meter readings and alphanumeric serial numbers.
 * @param {string} text - Raw text extracted by Tesseract.
 * @returns {Object} Extracted reading and serial number objects.
 */
const extractDataFromText = (text) => {
    let readingValue = null;
    let serialNumberExtracted = null;

    // Cleanup text
    const cleanedText = text.replace(/\n+/g, ' ').trim();

    // Heuristic 1: Look for 4 to 8 consecutive digits as the meter reading consumption.
    // We'll greedily find the longest matching number group or rely on specific patterns if business rules require.
    const readingMatch = cleanedText.match(/\b\d{4,8}\b/g);
    if (readingMatch && readingMatch.length > 0) {
        // Assuming the largest continuous block of numbers represents the main dial reading, or grab the first match.
        // Tweak heuristics based on actual meter templates.
        readingValue = parseInt(readingMatch[0], 10);
    }

    // Heuristic 2: Look for an alphanumeric sequence that could represent the serial number.
    // Example pattern: Starts with 1-3 letters followed by 5-8 numbers (e.g., MET1234567).
    const serialMatch = cleanedText.match(/\b[A-Z]{1,3}\d{5,8}\b/i);
    if (serialMatch && serialMatch.length > 0) {
        serialNumberExtracted = serialMatch[0].toUpperCase();
    }

    return { readingValue, serialNumberExtracted };
};

/**
 * Main OCR processing flow.
 * 
 * @param {string} imagePath - Path to the image on disk.
 * @returns {Promise<Object>} Results containing value, serial, and generic confidence.
 */
exports.processImage = async (imagePath) => {
    // 1. Preprocess
    const preprocessedBuffer = await preprocessImage(imagePath);

    // 2. Run Tesseract recognition
    // Tesseract accepts buffers directly
    const { data } = await Tesseract.recognize(
        preprocessedBuffer,
        'eng', // Language
        {
            logger: m => { } // Ignore logs for now to keep console clean. e.g console.log(m)
        }
    );

    // 3. Extract logic
    const text = data.text;
    const overallConfidence = data.confidence;

    const { readingValue, serialNumberExtracted } = extractDataFromText(text);

    return {
        readingValue,
        serialNumberExtracted,
        confidence: overallConfidence, // Note: This is overall page confidence; specific word confidence can be mapped if needed.
        rawText: text // Useful for debugging or manual review
    };
};
