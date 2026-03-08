const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const billController = require('../controllers/billController');

// @route   GET /api/bills
// @desc    Get all bills for authenticated user
// @access  Private
router.get(
    '/',
    authMiddleware,
    billController.getMyBills
);

// @route   GET /api/bills/:id
// @desc    Get a single bill by its ID
// @access  Private
router.get(
    '/:id',
    authMiddleware,
    billController.getBill
);

module.exports = router;
