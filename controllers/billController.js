const Bill = require('../models/Bill');
const Reading = require('../models/Reading');
const Meter = require('../models/Meter');

// @route   GET /api/bills
// @desc    Get all bills for the authenticated user (paginated)
// @access  Private
exports.getMyBills = async (req, res) => {
    try {
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 10;
        const startIndex = (page - 1) * limit;

        // 1. Find all meters belonging to the user
        const userMeters = await Meter.find({ userId: req.user.id });

        if (userMeters.length === 0) {
            return res.json({ success: true, count: 0, pagination: {}, data: [] });
        }
        const meterIds = userMeters.map(m => m._id);

        // 2. Find all readings for those meters
        const readings = await Reading.find({ meterId: { $in: meterIds } });
        if (readings.length === 0) {
            return res.json({ success: true, count: 0, pagination: {}, data: [] });
        }
        const readingIds = readings.map(r => r._id);

        // 3. Find bills linked to those readings, sorted by generation date newest first
        const bills = await Bill.find({ readingId: { $in: readingIds } })
            .populate({
                path: 'readingId',
                select: 'readingValue submissionTime billingPeriod imagePath meterId',
                populate: {
                    path: 'meterId',
                    select: 'serialNumber'
                }
            })
            .sort({ generatedDate: -1 })
            .skip(startIndex)
            .limit(limit);

        // Calculate pagination metadata
        const total = await Bill.countDocuments({ readingId: { $in: readingIds } });
        const pagination = {};

        if (startIndex + bills.length < total) {
            pagination.next = { page: page + 1, limit };
        }
        if (startIndex > 0) {
            pagination.prev = { page: page - 1, limit };
        }

        res.json({
            success: true,
            count: bills.length,
            pagination,
            data: bills
        });

    } catch (err) {
        console.error('Error in getMyBills:', err);
        res.status(500).json({
            success: false,
            message: 'Server Error retrieving bills',
            errors: [err.message]
        });
    }
};

// @route   GET /api/bills/:id
// @desc    Get a single bill by its ID
// @access  Private
exports.getBill = async (req, res) => {
    try {
        const bill = await Bill.findById(req.params.id)
            .populate({
                path: 'readingId',
                select: 'readingValue submissionTime billingPeriod imagePath validationStatus meterId',
                populate: {
                    path: 'meterId',
                    select: 'serialNumber userId',
                    populate: {
                        path: 'userId',
                        select: 'accountNumber fullName'
                    }
                }
            })
            .populate({
                path: 'previousReadingId',
                select: 'readingValue submissionTime'
            });

        if (!bill) {
            return res.status(404).json({
                success: false,
                message: 'Bill not found',
                errors: [`No bill found with id ${req.params.id}`]
            });
        }

        // Ensure the reading attached to the bill belongs to the authenticated user's meter
        // Using optional chaining because population can be deep
        const billUserId = bill.readingId?.meterId?.userId?._id?.toString();

        if (billUserId !== req.user.id) {
            return res.status(403).json({
                success: false,
                message: 'Unauthorized access to bill',
                errors: ['You do not have permission to view this specific bill']
            });
        }

        res.json({
            success: true,
            data: bill
        });

    } catch (err) {
        console.error('Error in getBill:', err);
        res.status(500).json({
            success: false,
            message: 'Server Error retrieving bill',
            errors: [err.message]
        });
    }
};
