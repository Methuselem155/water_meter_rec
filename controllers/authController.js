const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const User = require('../models/User');
const Meter = require('../models/Meter');

// @route   POST /api/auth/register
// @desc    Register a user and their meter
// @access  Public
exports.register = async (req, res) => {
    // Validate input
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Validation failed',
            errors: errors.array().map(err => err.msg)
        });
    }

    const { accountNumber, fullName, phoneNumber, password, meterSerialNumber, email, category } = req.body;

    try {
        // Check if user already exists
        let user = await User.findOne({ $or: [{ phoneNumber }, { accountNumber }] });
        if (user) {
            return res.status(400).json({
                success: false,
                message: 'Registration failed',
                errors: ['User with this phone number or account number already exists']
            });
        }

        // Check if meter serial number is already in use
        let existingMeter = await Meter.findOne({ serialNumber: meterSerialNumber });
        if (existingMeter) {
            return res.status(400).json({
                success: false,
                message: 'Registration failed',
                errors: ['Meter serial number is already registered to an account']
            });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(password, salt);

        // Create user object
        user = new User({
            accountNumber,
            fullName,
            phoneNumber,
            email: email || null,
            category: category || 'RESIDENTIAL',
            passwordHash
        });

        // Save user to DB
        await user.save();

        // Create and save meter object linked to user
        const meter = new Meter({
            serialNumber: meterSerialNumber,
            userId: user._id
        });
        await meter.save();

        // Create JWT payload
        const payload = {
            user: {
                id: user.id
            }
        };

        // Sign JWT
        const jwtSecret = process.env.JWT_SECRET;
        if (!jwtSecret) throw new Error('JWT_SECRET is not configured');
        jwt.sign(
            payload,
            jwtSecret,
            { expiresIn: process.env.JWT_EXPIRE || '7d' }, // typically expires in 7 days
            (err, token) => {
                if (err) throw err;
                res.status(201).json({
                    success: true,
                    message: 'User registered successfully',
                    data: {
                        token,
                        user: {
                            id: user.id,
                            accountNumber: user.accountNumber,
                            fullName: user.fullName,
                            phoneNumber: user.phoneNumber,
                            category: user.category
                        }
                    }
                });
            }
        );
    } catch (err) {
        console.error(err.message);
        res.status(500).json({
            success: false,
            message: 'Server Error',
            errors: [err.message]
        });
    }
};

// @route   POST /api/auth/login
// @desc    Authenticate user & get token
// @access  Public
exports.login = async (req, res) => {
    // Validate input
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            success: false,
            message: 'Validation failed',
            errors: errors.array().map(err => err.msg)
        });
    }

    const { phoneNumber, accountNumber, password } = req.body;
    const identifier = phoneNumber || accountNumber;

    try {
        // See if user exists using either phone or account number
        let user = await User.findOne({
            $or: [{ phoneNumber: identifier }, { accountNumber: identifier }]
        });

        if (!user) {
            return res.status(400).json({
                success: false,
                message: 'Invalid credentials',
                errors: ['Invalid phone number or account number']
            });
        }

        // Compare passwords
        const isMatch = await bcrypt.compare(password, user.passwordHash);

        if (!isMatch) {
            return res.status(400).json({
                success: false,
                message: 'Invalid credentials',
                errors: ['Invalid password']
            });
        }

        // Create JWT payload
        const payload = {
            user: {
                id: user.id
            }
        };

        // Sign JWT
        const jwtSecret = process.env.JWT_SECRET;
        if (!jwtSecret) throw new Error('JWT_SECRET is not configured');
        jwt.sign(
            payload,
            jwtSecret,
            { expiresIn: process.env.JWT_EXPIRE || '7d' },
            (err, token) => {
                if (err) throw err;
                res.json({
                    success: true,
                    message: 'Login successful',
                    data: {
                        token,
                        user: {
                            id: user.id,
                            accountNumber: user.accountNumber,
                            fullName: user.fullName,
                            phoneNumber: user.phoneNumber,
                            category: user.category
                        }
                    }
                });
            }
        );
    } catch (err) {
        console.error(err.message);
        res.status(500).json({
            success: false,
            message: 'Server Error',
            errors: [err.message]
        });
    }
};

// @route   GET /api/auth/me
// @desc    Get current user profile
// @access  Private
exports.getMe = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-passwordHash');
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
                errors: ['Current user account no longer exists in our records.']
            });
        }
        res.json({
            success: true,
            data: {
                user: {
                    id: user.id,
                    accountNumber: user.accountNumber,
                    fullName: user.fullName,
                    phoneNumber: user.phoneNumber,
                    email: user.email,
                    category: user.category
                }
            }
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).json({
            success: false,
            message: 'Server Error',
            errors: [err.message]
        });
    }
};

