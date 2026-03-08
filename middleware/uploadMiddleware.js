const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Configure storage
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // Generate unique filename: userId-timestamp.extension
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const userId = req.user ? req.user.id : 'anonymous';
        const ext = path.extname(file.originalname).toLowerCase();
        cb(null, `${userId}-${uniqueSuffix}${ext}`);
    }
});

// File filter to accept only images
const fileFilter = (req, file, cb) => {
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/jpg'];
    if (allowedMimeTypes.includes(file.mimetype)) {
        // Accept file
        cb(null, true);
    } else {
        // Reject file
        cb(new Error('Invalid file type. Only JPEG, JPG, and PNG images are allowed.'), false);
    }
};

// Initialize multer upload middleware
const uploadMiddleware = multer({
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024 // 10MB file size limit
    },
    fileFilter: fileFilter
});

module.exports = uploadMiddleware;
