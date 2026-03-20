#!/usr/bin/env node
/**
 * Direct OCR test - tests Tesseract without preprocessing first
 * Usage: node test-ocr-raw.js <path-to-image>
 */

const Tesseract = require('tesseract.js');
const fs = require('fs');
const path = require('path');

const testRawOCR = async (imagePath) => {
    console.log(`\n========================================`);
    console.log(`Testing RAW OCR (no preprocessing)`);
    console.log(`Image: ${imagePath}`);
    console.log(`========================================\n`);

    if (!fs.existsSync(imagePath)) {
        console.error(`✗ Image not found: ${imagePath}`);
        process.exit(1);
    }

    try {
        console.log(`[TEST] Running OCR on raw image (no preprocessing)...`);
        const result = await Tesseract.recognize(imagePath, 'eng', {
            logger: m => console.log(`[Tesseract] ${m.status}: ${(m.progress * 100).toFixed(0)}%`)
        });

        const { data } = result;
        const text = data.text || '';
        const confidence = data.confidence || 0;

        console.log(`\n========================================`);
        console.log(`RAW OCR RESULTS`);
        console.log(`========================================`);
        console.log(`Text length: ${text.length} chars`);
        console.log(`Confidence: ${confidence}`);
        console.log(`\nRaw text:\n"${text}"`);
        console.log(`\n========================================\n`);

        // Try to extract digits
        const denseText = text.replace(/\s/g, '');
        const digits = denseText.match(/\d+/g);
        console.log(`Digit sequences found: ${digits ? digits.join(', ') : 'NONE'}`);

        await worker.terminate();
        process.exit(0);

    } catch (error) {
        console.error(`✗ OCR Failed:`, error.message);
        process.exit(1);
    }
};

const imagePath = process.argv[2];
if (!imagePath) {
    console.error('Usage: node test-ocr-raw.js <path-to-image>');
    console.error('Example: node test-ocr-raw.js uploads/meter.jpg');
    process.exit(1);
}

testRawOCR(path.resolve(imagePath));
