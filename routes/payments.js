const express = require('express');
const router = express.Router();
const { initiateCashin, webhook, getStatus } = require('../controllers/paymentController');
const authMiddleware = require('../middleware/authMiddleware');

// Customer-facing — requires JWT
router.post('/cashin', authMiddleware, initiateCashin);
router.get('/status/:ref', authMiddleware, getStatus);

// Paypack webhook — server-to-server, no JWT (verified via HMAC)
router.post('/webhook', webhook);

module.exports = router;
