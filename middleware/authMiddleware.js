const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {
    // Get token from header
    const authHeader = req.header('Authorization');
    let token;

    if (authHeader && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7, authHeader.length);
    } else {
        // Also support token without Bearer prefix if provided directly
        token = authHeader;
    }

    // Check if no token
    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'No token, authorization denied',
            errors: ['Authorization token is required in the header']
        });
    }

    try {
        // Verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret_here');

        // Attach user payload to request
        req.user = decoded.user;
        next();
    } catch (err) {
        res.status(401).json({
            success: false,
            message: 'Token is not valid',
            errors: ['Invalid or expired authorization token']
        });
    }
};

module.exports = authMiddleware;
