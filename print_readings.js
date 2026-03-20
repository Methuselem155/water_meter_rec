#!/usr/bin/env node

require('dotenv').config();

const mongoose = require('mongoose');
const Reading = require('./models/Reading');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/water-meter';

async function main() {
  await mongoose.connect(MONGODB_URI);

  const readings = await Reading.find({})
    .sort({ submissionTime: -1 })
    .limit(10)
    .lean();

  for (const r of readings) {
    console.log(
      JSON.stringify(
        {
          id: r._id,
          submissionTime: r.submissionTime,
          imagePath: r.imagePath,
          readingValue: r.readingValue,
          serialNumberExtracted: r.serialNumberExtracted,
          validationStatus: r.validationStatus,
        },
        null,
        2,
      ),
    );
  }

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

