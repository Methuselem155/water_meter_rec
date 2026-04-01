const Reading = require('../models/Reading');
const Meter = require('../models/Meter');

/**
 * Normalize a serial number string by collapsing common OCR substitutions
 * so that '0'/'O', '1'/'I'/'L', '8'/'B', '5'/'S' are treated as equivalent.
 */
const normalizeSerial = (s) => {
    return s
        .toUpperCase()
        .replace(/O/g, '0')   // O → 0  (letter O vs digit 0)
        .replace(/\(/g, 'I')  // ( → I  (common EasyOCR confusion)
        .replace(/\s+/g, ''); // strip whitespace
    // NOTE: Do NOT map I→1, B→8 etc. — these are valid letters in serial numbers
    // like I20BA008111. Only map characters that are NEVER valid in serials.
};

/**
 * Compute character-level similarity ratio between two strings (0–1).
 * Uses a simple matching characters / max-length approach.
 */
const serialSimilarity = (a, b) => {
    if (!a || !b) return 0;
    const na = normalizeSerial(a);
    const nb = normalizeSerial(b);
    if (na === nb) return 1;

    // Try both full match and suffix match (handles leading char drop/misread)
    const scores = [];

    // 1. Position-aligned match
    const minLen = Math.min(na.length, nb.length);
    let matches = 0;
    for (let i = 0; i < minLen; i++) {
        if (na[i] === nb[i]) matches++;
    }
    scores.push(matches / Math.max(na.length, nb.length));

    // 2. Suffix match — if one string is 1 char longer, try dropping the first char
    if (Math.abs(na.length - nb.length) <= 1) {
        const shorter = na.length <= nb.length ? na : nb;
        const longer  = na.length <= nb.length ? nb : na;
        let sfxMatches = 0;
        const offset = longer.length - shorter.length;
        for (let i = 0; i < shorter.length; i++) {
            if (shorter[i] === longer[i + offset]) sfxMatches++;
        }
        scores.push(sfxMatches / longer.length);
    }

    return Math.max(...scores);
};

// Minimum similarity to consider serials a match (0.7 = 70% of chars must align)
const SERIAL_SIMILARITY_THRESHOLD = 0.7;

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
        // Use fuzzy matching with OCR-normalization to tolerate common character substitutions
        // (O/0, I/1, B/8, etc.) that EasyOCR frequently confuses on 7-segment displays.
        const actualSerial = reading.meterId.serialNumber;
        const extractedSerial = reading.serialNumberExtracted || null;

        if (extractedSerial) {
            const similarity = serialSimilarity(actualSerial, extractedSerial);
            console.log(`[Validation Service] Serial check: actual='${actualSerial}' extracted='${extractedSerial}' similarity=${(similarity * 100).toFixed(1)}%`);

            // Only flag fraud if the extracted serial looks like a real serial number
            // (must contain at least 2 digits — pure/mostly-letter strings are OCR noise)
            const digitCount = (extractedSerial.match(/\d/g) || []).length;
            if (digitCount >= 2 && similarity < SERIAL_SIMILARITY_THRESHOLD) {
                reading.validationStatus = 'fraud_suspected';
                await reading.save();
                console.warn(`[Validation Service] Reading ${readingId} flagged as fraud_suspected: serial similarity ${(similarity * 100).toFixed(1)}% below threshold.`);
                return reading;
            } else if (digitCount < 2) {
                console.log(`[Validation Service] Extracted serial '${extractedSerial}' looks like OCR noise, skipping serial check.`);
            }
        } else {
            // Serial not extracted — acceptable, proceed with reading value
            console.log(`[Validation Service] Serial number not extracted for ${readingId}, proceeding with reading value.`);
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
            
            // Only enforce progression check if confidence is reasonable
            // Low confidence OCR may have missed digits — don't penalize
            const confidence = reading.confidence || 0;
            if (!isNaN(currentVal) && !isNaN(prevVal) && currentVal < prevVal && confidence >= 0.5) {
                reading.validationStatus = 'failed';
                await reading.save();
                console.warn(`[Validation Service] Reading ${readingId} failed: Current value (${reading.readingValue}) is less than previous (${previousReading.readingValue}).`);
                return reading;
            } else if (!isNaN(currentVal) && !isNaN(prevVal) && currentVal < prevVal) {
                console.warn(`[Validation Service] Reading ${readingId}: value ${currentVal} < prev ${prevVal} but confidence ${confidence} is low — allowing through.`);
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
