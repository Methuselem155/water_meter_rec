const express = require('express');
const router = express.Router();
const adminMiddleware = require('../middleware/adminMiddleware');
const adminController = require('../controllers/adminController');

router.get('/stats',        adminMiddleware, adminController.getStats);
router.get('/users',        adminMiddleware, adminController.getUsers);
router.post('/users',       adminMiddleware, adminController.createUser);
router.delete('/users/:id', adminMiddleware, adminController.deleteUser);
router.post('/reset',       adminMiddleware, adminController.resetSystem);

// Meter routes
router.get('/meters', adminMiddleware, adminController.getMeters);

// Reading routes
router.get('/readings',            adminMiddleware, adminController.getReadings);
router.put('/readings/:id/status', adminMiddleware, adminController.updateReadingStatus);
router.delete('/readings/:id',     adminMiddleware, adminController.deleteReading);

// Bill routes
router.get('/bills/summary',               adminMiddleware, adminController.getBillsSummary);
router.patch('/bills/mark-overdue',        adminMiddleware, adminController.markOverdue);
router.get('/bills',                       adminMiddleware, adminController.getAdminBills);
router.patch('/bills/:id/confirm-payment', adminMiddleware, adminController.confirmPayment);

module.exports = router;
