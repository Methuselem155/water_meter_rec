require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// Connect to MongoDB
const connectDB = async () => {
  try {
    // Determine the URI to use, fallback to localhost if missing (for safety during testing)
    const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/water-meter';
    await mongoose.connect(uri);
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
app.use(cors()); // Note: In production, specify specific allowed origin (e.g., origin: 'https://admin-panel.com')

// 4. Payload Parsing
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies

// 5. Static Folders (Exposing the images for development review)
// Caution: Ensure no sensitive data lives here, or attach authMiddleware protecting it.
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/readings', require('./routes/readingRoutes'));
app.use('/api/bills', require('./routes/billRoutes'));

// Simple test route
app.get('/', (req, res) => {
  res.json({ message: 'Water Meter Backend Server is running.' });
});

// Global Error Handler (Must be mounted last to catch cascading throw commands)
app.use(errorHandler);

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
