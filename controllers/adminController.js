const User = require('../models/User');
const Meter = require('../models/Meter');
const Reading = require('../models/Reading');
const Bill = require('../models/Bill');

exports.getDashboardStats = async (req, res) => {
    try {
        const totalUsers = await User.countDocuments({ role: 'user' });
        const totalMeters = await Meter.countDocuments();
        
        const pendingReadingsCount = await Reading.countDocuments({ validationStatus: 'pending' });
        const totalReadings = await Reading.countDocuments();
        
        const totalBills = await Bill.countDocuments();
        const paidBills = await Bill.countDocuments({ status: 'paid' });
        
        // Calculate total revenue from final/paid bills
        const bills = await Bill.find({ status: { $in: ['final', 'paid'] } });
        const totalRevenue = bills.reduce((sum, bill) => sum + (bill.totalAmountVatInclusive || 0), 0);

        res.json({
            success: true,
            data: {
                totalUsers,
                totalMeters,
                totalReadings,
                pendingReadingsCount,
                totalBills,
                paidBills,
                totalRevenue
            }
        });
    } catch (err) {
        console.error('[AdminController] getDashboardStats error:', err);
        res.status(500).json({ success: false, message: 'Server Error', error: err.message });
    }
};

exports.getAllUsers = async (req, res) => {
    try {
        const users = await User.find({ role: 'user' }).select('-passwordHash').sort({ createdAt: -1 });
        res.json({ success: true, count: users.length, data: users });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

exports.getAllMeters = async (req, res) => {
    try {
        const meters = await Meter.find().populate('userId', 'fullName accountNumber phoneNumber').sort({ installationDate: -1 });
        res.json({ success: true, count: meters.length, data: meters });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

exports.getAllReadings = async (req, res) => {
    try {
        const readings = await Reading.find()
            .populate({
                path: 'meterId',
                select: 'serialNumber',
                populate: { path: 'userId', select: 'fullName accountNumber' }
            })
            .sort({ submissionTime: -1 });
            
        res.json({ success: true, count: readings.length, data: readings });
    } catch (err) {
        console.error('[AdminController] getAllReadings error:', err);
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

exports.getAllBills = async (req, res) => {
    try {
        const bills = await Bill.find()
            .populate('userId', 'fullName accountNumber phoneNumber')
            .populate('readingId', 'readingValue submissionTime imagePath')
            .sort({ generatedDate: -1 });
            
        res.json({ success: true, count: bills.length, data: bills });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

exports.updateReadingStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { validationStatus, readingValue } = req.body;

        const reading = await Reading.findById(id);
        if (!reading) {
            return res.status(404).json({ success: false, message: 'Reading not found' });
        }

        if (validationStatus) {
            reading.validationStatus = validationStatus;
        }
        
        if (readingValue !== undefined) {
            reading.readingValue = readingValue;
            
            // Re-trigger bill generation or logic if needed here, 
            // but for now just updating the reading value
        }

        await reading.save();

        res.json({ success: true, data: reading });
    } catch (err) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};
