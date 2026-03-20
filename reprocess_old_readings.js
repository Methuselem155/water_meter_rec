#!/usr/bin/env node
/**
 * Re-run OCR (Python/pytesseract) for all existing readings
 * that have an imagePath but no readingValue yet.
 *
 * Usage:
 *   node reprocess_old_readings.js
 */

require('dotenv').config();

const mongoose = require('mongoose');
const path = require('path');

const Reading = require('./models/Reading');
const ocrService = require('./services/ocrService');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/water-meter';

async function main() {
  await mongoose.connect(MONGODB_URI);
  console.log('[Reprocess] Connected to MongoDB');

  const cursor = Reading.find({
    imagePath: { $ne: null },
    readingValue: null,
  }).cursor();

  let processed = 0;
  for (let reading = await cursor.next(); reading != null; reading = await cursor.next()) {
    try {
      let absolutePath = reading.imagePath;
      if (!path.isAbsolute(absolutePath)) {
        absolutePath = path.join(__dirname, absolutePath);
      }

      console.log(`[Reprocess] Running OCR for reading ${reading._id} from ${absolutePath}`);
      const ocrResult = await ocrService.processImage(absolutePath);

      reading.readingValue = ocrResult.readingValue;
      reading.serialNumberExtracted = ocrResult.serialNumberExtracted;
      reading.confidence = ocrResult.confidence;
      reading.ocrRawText = ocrResult.rawText || null;

      await reading.save();
      processed += 1;

      console.log(
        `[Reprocess] Updated reading ${reading._id}: value=${reading.readingValue}, serial=${reading.serialNumberExtracted}`
      );
    } catch (err) {
      console.error(`[Reprocess] Failed OCR for reading ${reading._id}:`, err.message);
    }
  }

  console.log(`[Reprocess] Done. Updated ${processed} readings.`);
  await mongoose.disconnect();
  process.exit(0);
}

main().catch((err) => {
  console.error('[Reprocess] Fatal error:', err);
  process.exit(1);
});

