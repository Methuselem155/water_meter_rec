#!/usr/bin/env node
/**
 * Diagnostic script to test OCR processing independently
 * Usage: node test-ocr.js <path-to-image>
 */

const ocrService = require('./services/ocrService');
const fs = require('fs');
const path = require('path');

const testOCR = async (imagePath) => {
    console.log(`\n========================================`);
    console.log(`Testing OCR with image: ${imagePath}`);
    console.log(`========================================\n`);

    if (!fs.existsSync(imagePath)) {
        console.error(`Error: Image file not found at ${imagePath}`);
        process.exit(1);
    }

    try {
        console.log('Starting OCR processing...\n');
        const result = await ocrService.processImage(imagePath);

        console.log(`\n========================================`);
        console.log(`OCR Results:`);
        console.log(`========================================`);
        console.log(`Reading Value: ${result.readingValue || 'NOT EXTRACTED'}`);
        console.log(`Serial Number: ${result.serialNumberExtracted || 'NOT EXTRACTED'}`);
        console.log(`Confidence: ${(result.confidence * 100).toFixed(2)}%`);
        console.log(`Raw Text:\n${result.rawText}\n`);

        // Cleanup
        console.log(`OCR Worker terminated (No-op in python version)`);
        process.exit(0);

    } catch (error) {
        console.error(`\nERROR during OCR processing:`);
        console.error(error.message);
        console.error(error.stack);
        
        // Cleanup on error
        process.exit(1);
    }
};

// Get image path from command line arguments
const imagePath = process.argv[2];
if (!imagePath) {
    console.error('Usage: node test-ocr.js <path-to-image>');
    console.error('Example: node test-ocr.js uploads/test-meter.jpg');
    process.exit(1);
}

testOCR(path.resolve(imagePath));
