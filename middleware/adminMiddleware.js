const User = require('../models/User');

const adminMiddleware = async (req, res, next) => {
    try {
        // req.user is set by authMiddleware
        if (!req.user || !req.user.id) {
            return res.status(401).json({ success: false, message: 'Not authorized' });
        }

        const user = await User.findById(req.user.id);
        
        if (!user || user.role !== 'admin') {
            return res.status(403).json({ success: false, message: 'Forbidden: Admin access required' });
        }

        next();
    } catch (err) {
        console.error('[AdminMiddleware] Error:', err);
        res.status(500).json({ success: false, message: 'Server error verifying admin status' });
    }
};

module.exports = adminMiddleware;
