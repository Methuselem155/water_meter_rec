/**
 * Global Error Handling Middleware
 * Catch-all for unhandled routes and thrown exceptions.
 */
const errorHandler = (err, req, res, next) => {
    console.error('[Error Handler] Caught execution error:', err.stack);

    const statusCode = res.statusCode === 200 ? 500 : res.statusCode;

    res.status(statusCode).json({
        success: false,
        message: err.message || 'Internal Server Error',
        // Only leak stack trace details to API consumer when running locally in development mode
        error: process.env.NODE_ENV === 'production' ? 'An unexpected error occurred' : err.stack
    });
};

module.exports = errorHandler;
