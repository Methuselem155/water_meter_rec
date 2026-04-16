const authMiddleware = require('./authMiddleware');
const User = require('../models/User');

// Verify JWT then check role === 'admin'
const adminMiddleware = async (req, res, next) => {
    // First run JWT auth
    authMiddleware(req, res, async () => {
        try {
            const user = await User.findById(req.user.id).select('role');
            if (!user || user.role !== 'admin') {
                return res.status(403).json({ success: false, message: 'Admin access required' });
            }
            next();
        } catch (err) {
            res.status(500).json({ success: false, message: err.message });
        }
    });
};

module.exports = adminMiddleware;
