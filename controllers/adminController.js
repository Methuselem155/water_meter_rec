const User = require('../models/User');
const Meter = require('../models/Meter');
const Reading = require('../models/Reading');
const Bill = require('../models/Bill');
const bcrypt = require('bcrypt');

// @route   GET /api/admin/stats
// @desc    Dashboard summary stats
// @access  Admin
exports.getStats = async (req, res) => {
    try {
        const [totalUsers, totalMeters, totalReadings, totalBills, pendingReadingsCount, revenueResult] = await Promise.all([
            User.countDocuments({ role: 'user' }),
            Meter.countDocuments(),
            Reading.countDocuments(),
            Bill.countDocuments(),
            Reading.countDocuments({ validationStatus: 'pending' }),
            Bill.aggregate([
                { $match: { status: 'paid' } },
                { $group: { _id: null, total: { $sum: '$totalAmountVatInclusive' } } },
            ]),
        ]);
        const totalRevenue = revenueResult[0]?.total || 0;
        res.json({ success: true, data: { totalUsers, totalMeters, totalReadings, totalBills, pendingReadingsCount, totalRevenue } });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   GET /api/admin/users
// @desc    Get all registered users
// @access  Admin
exports.getUsers = async (req, res) => {
    try {
        const users = await User.find({ role: 'user' })
            .select('-passwordHash')
            .sort({ createdAt: -1 });

        // Attach meter info to each user
        const usersWithMeters = await Promise.all(users.map(async (user) => {
            const meter = await Meter.findOne({ userId: user._id }).select('serialNumber status');
            return { ...user.toObject(), meter: meter || null };
        }));

        res.json({ success: true, data: usersWithMeters });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   POST /api/admin/users
// @desc    Create a new user + meter (admin side)
// @access  Admin
exports.createUser = async (req, res) => {
    try {
        const { accountNumber, fullName, phoneNumber, password, meterSerialNumber, email, category } = req.body;

        if (!accountNumber || !fullName || !phoneNumber || !password || !meterSerialNumber || !category) {
            return res.status(400).json({ success: false, message: 'All fields are required' });
        }

        const existing = await User.findOne({ $or: [{ phoneNumber }, { accountNumber }] });
        if (existing) {
            return res.status(400).json({ success: false, message: 'User with this phone or account number already exists' });
        }

        const existingMeter = await Meter.findOne({ serialNumber: meterSerialNumber });
        if (existingMeter) {
            return res.status(400).json({ success: false, message: 'Meter serial number already registered' });
        }

        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(password, salt);

        const user = new User({ accountNumber, fullName, phoneNumber, email: email || null, category, passwordHash, role: 'user' });
        await user.save();

        const meter = new Meter({ serialNumber: meterSerialNumber, userId: user._id });
        await meter.save();

        res.status(201).json({
            success: true,
            message: 'User created successfully',
            data: { user: { ...user.toObject(), passwordHash: undefined }, meter }
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   GET /api/admin/meters
// @desc    Get all meters with owner info
// @access  Admin
exports.getMeters = async (req, res) => {
    try {
        const meters = await Meter.find()
            .populate({ path: 'userId', select: 'fullName accountNumber category' })
            .sort({ installationDate: -1 });
        res.json({ success: true, data: meters });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   GET /api/admin/readings
// @desc    Get all readings with meter and user info
// @access  Admin
exports.getReadings = async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 50));
        const skip = (page - 1) * limit;

        const [readings, total] = await Promise.all([
            Reading.find()
                .populate({
                    path: 'meterId',
                    select: 'serialNumber userId',
                    populate: { path: 'userId', select: 'fullName accountNumber' },
                })
                .sort({ submissionTime: -1 })
                .skip(skip)
                .limit(limit),
            Reading.countDocuments(),
        ]);

        res.json({ success: true, count: readings.length, total, data: readings });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   PUT /api/admin/readings/:id/status
// @desc    Update a reading's validation status
// @access  Admin
exports.updateReadingStatus = async (req, res) => {
    try {
        const { validationStatus } = req.body;
        const allowed = ['pending', 'validated', 'failed', 'fraud_suspected'];
        if (!validationStatus || !allowed.includes(validationStatus)) {
            return res.status(400).json({ success: false, message: `validationStatus must be one of: ${allowed.join(', ')}` });
        }

        const reading = await Reading.findByIdAndUpdate(
            req.params.id,
            { validationStatus },
            { new: true }
        ).populate({
            path: 'meterId',
            select: 'serialNumber userId',
            populate: { path: 'userId', select: 'fullName accountNumber' },
        });

        if (!reading) return res.status(404).json({ success: false, message: 'Reading not found' });

        res.json({ success: true, data: reading });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   DELETE /api/admin/readings/:id
// @desc    Delete a single reading and its associated bill
// @access  Admin
exports.deleteReading = async (req, res) => {
    try {
        const reading = await Reading.findById(req.params.id);
        if (!reading) return res.status(404).json({ success: false, message: 'Reading not found' });

        // Remove associated bill if it exists
        await Bill.deleteMany({ readingId: reading._id });
        await reading.deleteOne();

        res.json({ success: true, message: 'Reading deleted successfully' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   POST /api/admin/reset
// @desc    Delete all readings, bills, meters, and non-admin users
// @access  Admin
exports.resetSystem = async (req, res, next) => {
    try {
        const [deletedReadings, deletedBills, deletedMeters, deletedUsers] = await Promise.all([
            Reading.deleteMany({}),
            Bill.deleteMany({}),
            Meter.deleteMany({}),
            User.deleteMany({ role: { $ne: 'admin' } }),
        ]);

        res.json({
            success: true,
            data: {
                deletedReadings: deletedReadings.deletedCount,
                deletedBills: deletedBills.deletedCount,
                deletedMeters: deletedMeters.deletedCount,
                deletedUsers: deletedUsers.deletedCount,
            },
        });
    } catch (err) {
        next(err);
    }
};

// @route   GET /api/admin/bills
// @desc    Get all bills (paginated) with payment fields
// @access  Admin
exports.getAdminBills = async (req, res) => {
    try {
        const page = Math.max(1, parseInt(req.query.page, 10) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
        const skip = (page - 1) * limit;

        const [bills, total] = await Promise.all([
            Bill.find()
                .populate({ path: 'readingId', select: 'readingValue submissionTime billingPeriod meterId' })
                .populate({ path: 'userId', select: 'accountNumber fullName phoneNumber' })
                .select('status dueDate paidAt paymentMethod paymentReference totalAmount totalAmountVatInclusive consumption category generatedDate readingId userId')
                .sort({ generatedDate: -1 })
                .skip(skip)
                .limit(limit),
            Bill.countDocuments(),
        ]);

        res.json({ success: true, count: bills.length, total, data: bills });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   GET /api/admin/bills/summary
// @desc    Count and amount totals grouped by payment status
// @access  Admin
exports.getBillsSummary = async (req, res) => {
    try {
        const [unpaid, paid, overdue] = await Promise.all([
            Bill.aggregate([
                { $match: { status: 'unpaid' } },
                { $group: { _id: null, count: { $sum: 1 }, totalAmount: { $sum: '$totalAmountVatInclusive' } } },
            ]),
            Bill.aggregate([
                { $match: { status: 'paid' } },
                { $group: { _id: null, count: { $sum: 1 } } },
            ]),
            Bill.aggregate([
                { $match: { status: 'overdue' } },
                { $group: { _id: null, count: { $sum: 1 }, totalAmount: { $sum: '$totalAmountVatInclusive' } } },
            ]),
        ]);

        res.json({
            success: true,
            data: {
                totalUnpaid:         unpaid[0]?.count       || 0,
                totalPaid:           paid[0]?.count         || 0,
                totalOverdue:        overdue[0]?.count      || 0,
                totalAmountUnpaid:   unpaid[0]?.totalAmount  || 0,
                totalAmountOverdue:  overdue[0]?.totalAmount || 0,
            },
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   PATCH /api/admin/bills/:id/confirm-payment
// @desc    Mark a bill as paid
// @access  Admin
exports.confirmPayment = async (req, res) => {
    try {
        const { paymentMethod, paymentReference } = req.body;
        const validMethods = ['momo', 'bank', 'cash'];

        if (!paymentMethod || !validMethods.includes(paymentMethod)) {
            return res.status(400).json({
                success: false,
                message: `paymentMethod must be one of: ${validMethods.join(', ')}`,
            });
        }

        const bill = await Bill.findById(req.params.id);
        if (!bill) return res.status(404).json({ success: false, message: 'Bill not found' });

        if (bill.status === 'paid') {
            return res.status(400).json({ success: false, message: 'Bill is already marked as paid' });
        }

        bill.status = 'paid';
        bill.paidAt = new Date();
        bill.paymentMethod = paymentMethod;
        bill.paymentReference = paymentReference || null;
        await bill.save();

        await bill.populate({ path: 'userId', select: 'accountNumber fullName phoneNumber' });

        res.json({ success: true, data: bill });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   PATCH /api/admin/bills/mark-overdue
// @desc    Bulk-update unpaid bills past their dueDate to overdue
// @access  Admin
exports.markOverdue = async (req, res) => {
    try {
        const result = await Bill.updateMany(
            { status: 'unpaid', dueDate: { $lt: new Date() } },
            { $set: { status: 'overdue' } }
        );
        res.json({ success: true, data: { updatedCount: result.modifiedCount } });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// @route   DELETE /api/admin/users/:id
// @desc    Delete a user and all their data
// @access  Admin
exports.deleteUser = async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });
        if (user.role === 'admin') return res.status(403).json({ success: false, message: 'Cannot delete admin accounts' });

        // Delete all associated data
        const meters = await Meter.find({ userId: user._id });
        const meterIds = meters.map(m => m._id);
        const readings = await Reading.find({ meterId: { $in: meterIds } });
        const readingIds = readings.map(r => r._id);

        await Bill.deleteMany({ readingId: { $in: readingIds } });
        await Reading.deleteMany({ meterId: { $in: meterIds } });
        await Meter.deleteMany({ userId: user._id });
        await User.findByIdAndDelete(user._id);

        res.json({ success: true, message: 'User and all associated data deleted' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};
