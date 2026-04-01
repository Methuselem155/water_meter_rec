const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');

// All routes require authentication and admin role
router.use(authMiddleware, adminMiddleware);

// Dashboard stats
router.get('/stats', adminController.getDashboardStats);

// Users
router.get('/users', adminController.getAllUsers);

// Meters
router.get('/meters', adminController.getAllMeters);

// Readings
router.get('/readings', adminController.getAllReadings);
router.put('/readings/:id/status', adminController.updateReadingStatus);

// Bills
router.get('/bills', adminController.getAllBills);

module.exports = router;
