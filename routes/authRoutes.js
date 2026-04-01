const express = require('express');
const router = express.Router();
const { check } = require('express-validator');
const rateLimit = require('express-rate-limit');
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// Define brute-force protection logic specifically for auth to lock rapid guessing
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes window timeframe
    max: 20, // limit each IP to 20 auth attempts per window
    message: {
        success: false,
        message: 'Too many authentication attempts from this IP. Please try again after 15 minutes.'
    }
});

// @route   POST /api/auth/register
// @desc    Register a new user and map to a water meter
// @access  Public
router.post(
    '/register',
    authLimiter,
    [
        check('accountNumber', 'Account number is required').not().isEmpty(),
        check('fullName', 'Full name is required').not().isEmpty(),
        check('phoneNumber', 'Phone number is required').not().isEmpty(),
        check('password', 'Please enter a password with 6 or more characters').isLength({ min: 6 }),
        check('meterSerialNumber', 'Meter serial number is required').not().isEmpty(),
        check('category', 'Customer category is required').isIn(['PUBLIC TAP', 'RESIDENTIAL', 'NON RESIDENTIAL', 'INDUSTRIES'])
    ],
    authController.register
);

// @route   POST /api/auth/login
// @desc    Authenticate user & get token
// @access  Public
router.post(
    '/login',
    authLimiter,
    [
        check('password', 'Password is required').exists()
    ],
    (req, res, next) => {
        // Custom validation to ensure either phone or account number is provided
        if (!req.body.phoneNumber && !req.body.accountNumber) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: ['Please provide either phoneNumber or accountNumber to login']
            });
        }
        next();
    },
    authController.login
);

// @route   GET /api/auth/me
// @desc    Get current user profile
// @access  Private
router.get('/me', authMiddleware, authController.getMe);

module.exports = router;
