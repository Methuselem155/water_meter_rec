const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const uploadMiddleware = require('../middleware/uploadMiddleware');
const readingController = require('../controllers/readingController');
const rateLimit = require('express-rate-limit');

const uploadLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 Hour restriction
    max: 30, // Limit each IP to 30 uploads per hour max
    message: {
        success: false,
        message: 'Upload quota limit exceeded. Please try again later.'
    }
});

// Multer error handling wrapper for cleaner response messaging
const handleUpload = (req, res, next) => {
    const upload = uploadMiddleware.single('image');

    upload(req, res, function (err) {
        if (err) {
            // Multer throws different err types, e.g., size limit or custom filter error
            return res.status(400).json({
                success: false,
                message: 'Upload error',
                errors: [err.message]
            });
        }
        // Everything okay
        next();
    });
};

// @route   POST /api/readings/upload
// @desc    Upload meter image and create a new reading
// @access  Private
router.post(
    '/upload',
    uploadLimiter,
    authMiddleware,      // Check token
    handleUpload,        // Handle form-data (req.file)
    readingController.uploadReading
);

// @route   GET /api/readings/:id
// @desc    Get a single reading by its ID
// @access  Private
router.get(
    '/:id',
    authMiddleware,
    readingController.getReadingById
);

// @route   GET /api/readings
// @desc    Get all readings for authenticated user
// @access  Private
router.get(
    '/',
    authMiddleware,
    readingController.getMyReadings
);

module.exports = router;
