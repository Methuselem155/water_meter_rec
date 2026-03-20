const Reading = require('../models/Reading');
const Meter = require('../models/Meter');
const Bill = require('../models/Bill');
const { runOcrJob } = require('../workers/ocrWorker');
const ocrService = require('../services/ocrService');
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

        // Ensure the reading belongs to the authenticated user's meter
        if (reading.meterId.userId._id.toString() !== req.user.id) {
            return res.status(403).json({
                success: false,
                message: 'Unauthorized access to reading',
                errors: ['You do not have permission to view this specific reading']
            });
        }

        // If OCR previously failed or never populated, try a one-off re-run to permanently fix older records.
        if (!reading.readingValue && reading.imagePath) {
            try {
                let absolutePath = reading.imagePath;
                if (!path.isAbsolute(absolutePath)) {
                    absolutePath = path.join(__dirname, '..', absolutePath);
                }

                console.log(`[GetReadingById] Re-running OCR for reading ${reading._id} from ${absolutePath}`);
                const ocrResult = await ocrService.processImage(absolutePath);

                reading.readingValue = ocrResult.readingValue;
                reading.serialNumberExtracted = ocrResult.serialNumberExtracted;
                reading.confidence = ocrResult.confidence;
                reading.ocrRawText = ocrResult.rawText || null;

                await reading.save();
                console.log(`[GetReadingById] OCR re-run completed for reading ${reading._id}, value=${reading.readingValue}`);
            } catch (reErr) {
                console.error(`[GetReadingById] OCR re-run failed for reading ${reading._id}:`, reErr);
            }
        }

        // Try to find if a bill was generated for this reading
        const bill = await Bill.findOne({ readingId: reading._id }).select('-__v');

        const readingObj = reading.toObject ? reading.toObject() : reading;
        res.json({
            success: true,
            data: {
                reading: {
                    ...readingObj,
                    extracted: readingObj.ocrRawText ?? null
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
        
        // Store only the relative path from 'uploads' folder for proper HTTP serving
        // Handle both Windows and Unix paths consistently
        let imagePath = req.file.path;
        
        // Convert absolute path to relative
        if (imagePath.includes('uploads')) {
            const uploadsIndex = imagePath.toLowerCase().indexOf('uploads');
            imagePath = imagePath.substring(uploadsIndex);
        } else {
            // If no uploads folder in path, just use filename
            imagePath = path.basename(imagePath);
        }
        
        // Normalize separators to forward slashes for consistency
        imagePath = imagePath.replace(/\\/g, '/');
        
        console.log(`[Upload] Original absolute path: ${req.file.path}`);
        console.log(`[Upload] Storing relative imagePath: ${imagePath}`);

        // Create a new Reading document
        const newReading = new Reading({
            meterId: meter._id,
            imagePath: imagePath,
            validationStatus: 'pending',    // Set initially to pending pending OCR logic
            submissionTime: new Date(),
            billingPeriod: getBillingPeriod()
        });

        const savedReading = await newReading.save();
        console.log(`[Upload] Reading saved successfully with ID: ${savedReading._id}`);
        console.log(`[Upload] Reading data: meterId=${savedReading.meterId}, imagePath=${savedReading.imagePath}, validationStatus=${savedReading.validationStatus}`);

        // Determine if client wants to await OCR processing
        const awaitOcr = req.query.awaitOcr === 'true' || req.query.awaitOcr === true;

        if (awaitOcr) {
            console.log(`[Upload] Attempting synchronous OCR for reading ${savedReading._id}`);
            // Await OCR job completion (runOcrJob returns a promise if we modify it accordingly)
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
                        extracted: fullReadingObj.ocrRawText ?? null
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
                message: 'Reading uploaded successfully. Processing image in background.',
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
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 10;
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
