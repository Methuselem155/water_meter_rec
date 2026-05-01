const crypto = require('crypto');
const Bill = require('../models/Bill');
const paypack = require('../services/paypackService');

// POST /api/payments/cashin
exports.initiateCashin = async (req, res) => {
    const { billId, phoneNumber } = req.body;

    if (!billId || !phoneNumber) {
        return res.status(400).json({
            success: false,
            message: 'billId and phoneNumber are required',
        });
    }

    try {
        const bill = await Bill.findById(billId).populate({
            path: 'readingId',
            select: 'meterId',
            populate: { path: 'meterId', select: 'userId' },
        });

        if (!bill) {
            return res.status(404).json({ success: false, message: 'Bill not found' });
        }

        // Verify the bill belongs to the authenticated user
        const billOwnerId = bill.readingId?.meterId?.userId?.toString();
        if (billOwnerId !== req.user.id) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        if (bill.paymentStatus === 'paid') {
            return res.status(409).json({ success: false, message: 'Bill is already paid' });
        }

        const amount = bill.totalAmountVatInclusive ?? bill.totalAmount;

        const result = await paypack.cashin(amount, phoneNumber);

        await Bill.findByIdAndUpdate(billId, {
            paypackRef: result.ref,
            paymentStatus: 'pending_payment',
            paymentPhone: phoneNumber,
            paymentMethod: 'paypack',
        });

        res.json({ success: true, data: { ref: result.ref } });
    } catch (err) {
        console.error('[paymentController] cashin error:', err);
        res.status(502).json({
            success: false,
            message: err.message || 'Payment initiation failed',
        });
    }
};

// POST /api/payments/webhook  — called server-to-server by Paypack, no JWT auth
exports.webhook = async (req, res) => {
    // Verify HMAC signature when secret is configured
    const secret = process.env.PAYPACK_WEBHOOK_SECRET;
    if (secret) {
        const signature =
            req.headers['x-paypack-signature'] ||
            req.headers['x-webhook-signature'];
        const expected = crypto
            .createHmac('sha256', secret)
            .update(JSON.stringify(req.body))
            .digest('hex');
        if (signature !== expected) {
            return res.status(401).json({ success: false, message: 'Invalid webhook signature' });
        }
    }

    const { event, data } = req.body;

    if (!event || !data?.ref) {
        return res.status(400).json({ success: false, message: 'Invalid webhook payload' });
    }

    try {
        const bill = await Bill.findOne({ paypackRef: data.ref });

        // Acknowledge even if we don't recognise the ref
        if (!bill) return res.json({ received: true });

        const isSuccess =
            event === 'transaction:cashin:success' ||
            event === 'cashin:success';
        const isFailed =
            event === 'transaction:cashin:failed' ||
            event === 'cashin:failed';

        if (isSuccess) {
            await Bill.findByIdAndUpdate(bill._id, {
                paymentStatus: 'paid',
                status: 'paid',
                paidAt: new Date(),
            });
        } else if (isFailed) {
            await Bill.findByIdAndUpdate(bill._id, { paymentStatus: 'failed' });
        }

        res.json({ received: true });
    } catch (err) {
        console.error('[paymentController] webhook error:', err);
        res.status(500).json({ success: false, message: 'Webhook processing failed' });
    }
};

// GET /api/payments/status/:ref
exports.getStatus = async (req, res) => {
    const { ref } = req.params;

    try {
        const result = await paypack.getTransaction(ref);

        // Sync bill status from Paypack in case the webhook was missed
        const bill = await Bill.findOne({ paypackRef: ref });
        if (bill) {
            if (result.status === 'successful' && bill.paymentStatus !== 'paid') {
                await Bill.findByIdAndUpdate(bill._id, {
                    paymentStatus: 'paid',
                    status: 'paid',
                    paidAt: new Date(),
                });
            } else if (result.status === 'failed' && bill.paymentStatus !== 'failed') {
                await Bill.findByIdAndUpdate(bill._id, { paymentStatus: 'failed' });
            }
        }

        res.json({ success: true, data: result });
    } catch (err) {
        console.error('[paymentController] getStatus error:', err);
        res.status(502).json({
            success: false,
            message: err.message || 'Failed to retrieve transaction status',
        });
    }
};
