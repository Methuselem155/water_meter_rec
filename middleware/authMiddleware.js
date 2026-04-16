const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {
    // Get token from header — only the standard "Bearer <token>" format is accepted
    const authHeader = req.header('Authorization');

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            success: false,
            message: 'No token, authorization denied',
            errors: ['A Bearer token is required: Authorization: Bearer <token>']
        });
    }

    const token = authHeader.substring(7).trim();

    if (!token) {
        return res.status(401).json({
            success: false,
            message: 'No token, authorization denied',
            errors: ['Authorization token is required in the header']
        });
    }

    try {
        // Verify token
        const jwtSecret = process.env.JWT_SECRET;
        if (!jwtSecret) {
            console.error('[Auth] JWT_SECRET environment variable is not set');
            return res.status(500).json({
                success: false,
                message: 'Server configuration error',
                errors: ['Authentication service is misconfigured']
            });
        }
        const decoded = jwt.verify(token, jwtSecret);

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
