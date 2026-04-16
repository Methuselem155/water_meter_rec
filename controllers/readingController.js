const Reading = require('../models/Reading');
const Meter = require('../models/Meter');
const Bill = require('../models/Bill');
const { runOcrJob } = require('../workers/ocrWorker');
const ocrService = require('../services/ocrService');
const { processDisplay, processSerial } = ocrService;
const validationService = require('../services/validationService');
const billingService = require('../services/billingService');
const path = require('path');

// Helper to determine billing period (e.g. '2023-10')
const getBillingPeriod = () => {
    const date = new Date();
    const year = date.getFullYear();
    // Pad month with leading zero if needed
    const month = String(date.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
};



// @route   GET /api/readings/:id
// @desc    Get a single reading by its ID
// @access  Private
exports.getReadingById = async (req, res) => {
    try {
        const reading = await Reading.findById(req.params.id)
            .populate({
                path: 'meterId',
                select: 'serialNumber status userId',
                populate: {
                    path: 'userId',
                    select: 'accountNumber fullName phoneNumber'
                }
            });

        if (!reading) {
            return res.status(404).json({
                success: false,
                message: 'Reading not found',
                errors: [`No reading found with id ${req.params.id}`]
            });
        }

        // Ensure the reading belongs to the authenticated user's meter.
        // Guard against populate failure (deleted user / broken reference).
        const meterUserId = reading.meterId?.userId?._id;
        if (!meterUserId || meterUserId.toString() !== req.user.id) {
            return res.status(403).json({
                success: false,
                message: 'Unauthorized access to reading',
                errors: ['You do not have permission to view this specific reading']
            });
        }

        // Try to find if a bill was generated for this reading
        const bill = await Bill.findOne({ readingId: reading._id }).select('-__v');

        const readingObj = reading.toObject ? reading.toObject() : reading;
        res.json({
            success: true,
            data: {
                reading: {
                    ...readingObj,
                    extracted:         readingObj.ocrRawText     ?? null,
                    integer_reading:   readingObj.integerReading ?? null,
                    decimal_reading:   readingObj.decimalReading ?? null,
                    decimal_estimated: true,
                },
                bill: bill || null
            }
        });

    } catch (err) {
        console.error('Error in getReadingById:', err);
        res.status(500).json({
            success: false,
            message: 'Server Error retrieving reading',
            errors: [err.message]
        });
    }
};

// @route   POST /api/readings/upload
// @desc    Upload a meter reading image and trigger OCR processing
// @access  Private
exports.uploadReading = async (req, res) => {
    try {
        // Check if file was uploaded handled via multer
        if (!req.file) {
            console.error('[Upload] No file received in request');
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: ['No image file provided']
            });
        }

        const userId = req.user.id;
        console.log(`[Upload] Image received from user: ${userId}`);
        console.log(`[Upload] File saved to: ${req.file.path}`);

        // Find the user's active meter
        // Assuming 1 meter per user. If multiple, we would require a selected meterId in req.body
        const activeMeters = await Meter.find({ userId: userId, status: 'active' });

        if (activeMeters.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'No active meter found for this user',
                errors: ['User does not have an active meter registration.']
            });
        }

        if (activeMeters.length > 1) {
            return res.status(400).json({
                success: false,
                message: 'Multiple active meters found',
                errors: ['Please specify which meter this reading applies to.'] // Assuming we'd handle meter selection later if needed
            });
        }

        const meter = activeMeters[0];
        
        // Store relative path from project root (e.g. ocr_model/filename.jpg)
        const imagePath = 'ocr_model/' + path.basename(req.file.path);

        console.log(`[Upload] Image stored in OCR_test: ${imagePath}`);

        // Create a new Reading document
        // Validate manual readingValue if provided
        let manualReadingValue = null;
        let initialStatus = 'pending';
        if (req.body.readingValue !== undefined && req.body.readingValue !== null && req.body.readingValue !== '') {
            const parsed = Number(req.body.readingValue);
            if (isNaN(parsed) || parsed < 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Validation failed',
                    errors: ['readingValue must be a non-negative number']
                });
            }
            manualReadingValue = parsed;
            initialStatus = 'validated';
        }

        const newReading = new Reading({
            meterId: meter._id,
            imagePath: imagePath,
            readingValue: manualReadingValue,
            validationStatus: initialStatus,
            submissionTime: new Date(),
            billingPeriod: getBillingPeriod()
        });

        const savedReading = await newReading.save();
        console.log(`[Upload] Reading saved successfully with ID: ${savedReading._id}`);
        console.log(`[Upload] Reading data: meterId=${savedReading.meterId}, imagePath=${savedReading.imagePath}, validationStatus=${savedReading.validationStatus}`);

        // Default: background OCR so the mobile app does not time out waiting for Claude Vision.
        // Pass ?awaitOcr=true to opt into synchronous processing (useful for testing).
        const awaitOcr = req.query.awaitOcr === 'true';

        if (awaitOcr) {
            console.log(`[Upload] Attempting synchronous OCR for reading ${savedReading._id}`);

            await runOcrJob(savedReading._id);

            // Fetch full reading with populated meter and user info
            const fullReading = await Reading.findById(savedReading._id)
                .populate({
                    path: 'meterId',
                    select: 'serialNumber status userId',
                    populate: { path: 'userId', select: 'accountNumber fullName phoneNumber' }
                });
            console.log(`[Upload] Sync OCR completed for reading ${savedReading._id}`);
            const fullReadingObj = fullReading.toObject ? fullReading.toObject() : fullReading;
            return res.status(201).json({
                success: true,
                message: 'Reading uploaded and processed.',
                data: {
                    reading: {
                        ...fullReadingObj,
                        extracted:         fullReadingObj.ocrRawText     ?? null,
                        integer_reading:   fullReadingObj.integerReading ?? null,
                        decimal_reading:   fullReadingObj.decimalReading ?? null,
                        decimal_estimated: true,
                    }
                }
            });
        } else {
            console.log(`[Upload] Triggering asynchronous OCR for reading ${savedReading._id}`);

            // Trigger OCR job asynchronously without blocking the client.
            // NOTE: For production, replace `setImmediate` with a proper job queue
            // (e.g. BullMQ, RabbitMQ, AWS SQS) to guarantee delivery and handle retries.
            setImmediate(() => {
                runOcrJob(savedReading._id).catch(err => {
                    console.error(`[Upload] Async OCR job failed for ${savedReading._id}:`, err);
                });
            });

            return res.status(201).json({
                success: true,
                message: 'Reading uploaded. Processing image in background — poll GET /api/readings/:id for results.',
                data: {
                    readingId: savedReading._id,
                }
            });
        }
    } catch (err) {
        console.error('Error in uploadReading:', err);
        res.status(500).json({
            success: false,
            message: 'Server Error handling upload',
            errors: [err.message]
        });
    }
};

// @route   GET /api/readings
// @desc    Get all readings for the authenticated user (paginated)
// @access  Private
exports.getMyReadings = async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 10));
        const startIndex = (page - 1) * limit;

        console.log(`[GetReadings] Fetching readings for user ${req.user.id}, page ${page}, limit ${limit}`);

        // First find all meters belonging to the user
        const userMeters = await Meter.find({ userId: req.user.id });

        console.log(`[GetReadings] Found ${userMeters.length} meters for user ${req.user.id}`);
        if (userMeters.length > 0) {
            console.log(`[GetReadings] Meter IDs: ${userMeters.map(m => m._id).join(', ')}`);
        }

        if (userMeters.length === 0) {
            console.log(`[GetReadings] No meters found for user, returning empty result`);
            return res.json({
                success: true,
                count: 0,
                pagination: {},
                data: []
            });
        }

        const meterIds = userMeters.map(meter => meter._id);

        // Find readings for all user's meters, sorted by newest first
        const readings = await Reading.find({ meterId: { $in: meterIds } })
            .populate({
                path: 'meterId',
                select: 'serialNumber status'
            })
            .sort({ submissionTime: -1 })
            .skip(startIndex)
            .limit(limit);

        console.log(`[GetReadings] Found ${readings.length} readings for user's meters`);

        // Calculate pagination metadata
        const total = await Reading.countDocuments({ meterId: { $in: meterIds } });
        const hasNextPage = startIndex + readings.length < total;

        console.log(`[GetReadings] Total readings: ${total}, hasNextPage: ${hasNextPage}`);

        res.json({
            success: true,
            count: readings.length,
            pagination: hasNextPage ? { next: page + 1 } : {},
            data: readings
        });

    } catch (err) {
        console.error('Error in getMyReadings:', err);
        res.status(500).json({
            success: false,
            message: 'Server Error retrieving readings',
            errors: [err.message]
        });
    }
};

// @route   POST /api/readings/scan
// @desc    Receive two pre-cropped images (display + serial) and run focused OCR on each.
//          Creates and validates a reading in one shot. Much more accurate than full-image OCR.
// @access  Private
exports.scanReading = async (req, res) => {
    try {
        const userId = req.user.id;

        // Expect two files: 'display' (digit crop) and 'serial' (serial number crop)
        const displayFile = req.files?.display?.[0];
        const serialFile  = req.files?.serial?.[0];

        if (!displayFile) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: ['display crop image is required']
            });
        }

        // Find user's active meter
        const activeMeters = await Meter.find({ userId, status: 'active' });
        if (activeMeters.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'No active meter found',
                errors: ['User does not have an active meter registration.']
            });
        }
        const meter = activeMeters[0];

        const displayPath = displayFile.path;

        // First crop  → python ocr_model/ocr.py --image <path> --meter --no-boxes
        // Second crop → python ocr_model/ocr.py --image <path> --serial --no-boxes
        // Run in parallel when both crops are present for speed.
        console.log(`[Scan] Running --meter OCR on display crop: ${displayPath}`);

        let displayResult, serialResult;

        if (serialFile) {
            console.log(`[Scan] Running --serial OCR on serial crop: ${serialFile.path}`);
            [displayResult, serialResult] = await Promise.all([
                processDisplay(displayPath),
                processSerial(serialFile.path),
            ]);
        } else {
            displayResult = await processDisplay(displayPath);
            serialResult  = { serialNumberExtracted: null, confidence: 0, rawText: '' };
        }

        console.log(`[Scan] display OCR: value=${displayResult.readingValue} conf=${displayResult.confidence}`);
        console.log(`[Scan] serial OCR:  serial=${serialResult.serialNumberExtracted}`);

        // Store the display image as the reading image (in ocr_model/)
        const imagePath = 'ocr_model/' + path.basename(displayFile.path);

        // Create reading — persist integer/decimal split fields for the mobile display
        const newReading = new Reading({
            meterId: meter._id,
            imagePath,
            readingValue:          displayResult.readingValue,
            integerReading:        displayResult.integerPart   || null,
            decimalReading:        displayResult.fractionPart  || null,
            serialNumberExtracted: serialResult.serialNumberExtracted,
            confidence:            displayResult.confidence,
            ocrRawText:            displayResult.rawText || null,
            ocrMethod: 'claude-vision',
            validationStatus: 'pending',
            submissionTime: new Date(),
            billingPeriod: getBillingPeriod()
        });
        await newReading.save();

        // Run validation + billing
        const validated = await validationService.validateReading(newReading._id);
        if (validated.validationStatus === 'validated') {
            await billingService.generateBill(newReading._id);
        }

        // Return full reading with snake_case split fields Flutter expects
        const fullReading = await Reading.findById(newReading._id).populate({
            path: 'meterId',
            select: 'serialNumber status userId',
            populate: { path: 'userId', select: 'accountNumber fullName phoneNumber' }
        });

        const obj = fullReading.toObject();
        return res.status(201).json({
            success: true,
            message: 'Reading scanned and processed.',
            data: {
                reading: {
                    ...obj,
                    extracted:        obj.ocrRawText      ?? null,
                    integer_reading:  obj.integerReading  ?? null,
                    decimal_reading:  obj.decimalReading  ?? null,
                    decimal_estimated: true,
                }
            }
        });

    } catch (err) {
        console.error('Error in scanReading:', err);
        res.status(500).json({
            success: false,
            message: 'Server Error processing scan',
            errors: [err.message]
        });
    }
};
