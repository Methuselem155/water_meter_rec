require('dotenv').config({ override: true });
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const errorHandler = require('./middleware/errorHandler');
const authMiddleware = require('./middleware/authMiddleware');
const { terminateWorker } = require('./services/ocrService');

// Validate required environment variables before starting
const REQUIRED_ENV_VARS = ['JWT_SECRET', 'MONGODB_URI'];
const missingVars = REQUIRED_ENV_VARS.filter(v => !process.env[v]);
if (missingVars.length > 0) {
    console.error(`[Startup] Missing required environment variables: ${missingVars.join(', ')}`);
    console.error('[Startup] Please set them in your .env file. See .env.example for reference.');
    process.exit(1);
}

const app = express();
const PORT = process.env.PORT || 3000;

// Connect to MongoDB
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');
  } catch (error) {
    console.error('Error connecting to MongoDB:', error.message);
    process.exit(1);
  }
};

connectDB();

// Middleware Configurations
// 1. Security Headers
app.use(helmet({
  crossOriginResourcePolicy: false // Allow static image uploads to be fetched by the Flutter app
}));

// 2. HTTP Request Logging
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// 3. CORS limits
const allowedOrigins = process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
    : [];

app.use(cors({
    origin: (origin, callback) => {
        // Allow requests with no origin (mobile apps, curl, Postman)
        if (!origin) return callback(null, true);
        if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
            return callback(null, true);
        }
        callback(new Error(`CORS: Origin '${origin}' not allowed`));
    },
    credentials: true
}));

// 4. Payload Parsing
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies

// 5. Static Folders — protected by auth so only authenticated users can fetch meter images
app.use('/uploads', authMiddleware, express.static(path.join(__dirname, 'uploads')));
// ocr_model images — public so Image.network in Flutter can load without auth header
app.use('/ocr_model', express.static(path.join(__dirname, 'ocr_model')));

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/readings', require('./routes/readingRoutes'));
app.use('/api/bills', require('./routes/billRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));

// Simple test route
app.get('/', (req, res) => {
  res.json({ message: 'Water Meter Backend Server is running.' });
});

// Global Error Handler (Must be mounted last to catch cascading throw commands)
app.use(errorHandler);

// Start the server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on http://0.0.0.0:${PORT}`);
});

// Graceful shutdown handler
const gracefulShutdown = async () => {
  console.log('\nGracefully shutting down...');
  
  // Close server
  server.close(async () => {
    console.log('HTTP server closed');
    
    // Cleanup Tesseract workers
    await terminateWorker();
    
    // Close MongoDB connection
    await mongoose.disconnect();
    console.log('MongoDB connection closed');
    
    process.exit(0);
  });
};

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);
