const crypto = require('crypto');

const BASE_URL = 'https://payments.paypack.rw/api';
const TOKEN_TTL_MS = 14 * 60 * 1000; // Refresh 1 minute before the 15-min expiry

// ── Dev/mock mode ─────────────────────────────────────────────────────────────
// Set PAYPACK_MOCK=true in .env to bypass real API calls during development.
// Mock transactions auto-succeed after ~10 seconds (simulates user approval).
const MOCK_MODE = process.env.PAYPACK_MOCK === 'true';
const _mockStore = new Map(); // ref → { status, createdAt }

if (MOCK_MODE) {
    console.log('[Paypack] ⚠️  MOCK MODE enabled — no real money will move');
}

function mockCashin(amount, phoneNumber) {
    const ref = 'MOCK-' + crypto.randomBytes(8).toString('hex').toUpperCase();
    // Auto-succeed after 10 seconds
    _mockStore.set(ref, { status: 'pending', amount, number: phoneNumber, createdAt: Date.now() });
    setTimeout(() => {
        const entry = _mockStore.get(ref);
        if (entry) _mockStore.set(ref, { ...entry, status: 'successful' });
    }, 10_000);
    console.log(`[Paypack Mock] cashin → ref=${ref} amount=${amount} phone=${phoneNumber}`);
    return { ref };
}

function mockGetTransaction(ref) {
    const entry = _mockStore.get(ref);
    if (!entry) throw Object.assign(new Error('Transaction not found'), { status: 404 });
    const elapsed = Date.now() - entry.createdAt;
    const status = elapsed >= 10_000 ? 'successful' : 'pending';
    return { ref, status, amount: entry.amount, number: entry.number };
}

// ── HTTP helper with retry ────────────────────────────────────────────────────

let _token = null;
let _tokenExpiresAt = 0;

async function request(path, options = {}, retries = 2) {
    const url = `${BASE_URL}${path}`;
    let lastError;

    for (let attempt = 0; attempt <= retries; attempt++) {
        try {
            const res = await fetch(url, {
                ...options,
                headers: {
                    'Content-Type': 'application/json',
                    Accept: 'application/json',
                    ...options.headers,
                },
            });

            const body = await res.json();

            if (!res.ok) {
                const err = Object.assign(
                    new Error(body.message || `Paypack HTTP ${res.status}`),
                    { status: res.status, body }
                );
                throw err;
            }

            return body;
        } catch (err) {
            lastError = err;
            // Don't retry 4xx client errors — they won't change
            if (err.status >= 400 && err.status < 500) break;
            if (attempt < retries) {
                await new Promise(r => setTimeout(r, 300 * (attempt + 1)));
            }
        }
    }

    throw lastError;
}

// ── Token management ──────────────────────────────────────────────────────────

async function authenticate() {
    const body = await request('/auth/agents/authorize', {
        method: 'POST',
        body: JSON.stringify({
            client_id: process.env.PAYPACK_CLIENT_ID,
            client_secret: process.env.PAYPACK_CLIENT_SECRET,
        }),
    });

    _token = body.access;
    _tokenExpiresAt = Date.now() + TOKEN_TTL_MS;
}

async function getToken() {
    if (!_token || Date.now() >= _tokenExpiresAt) {
        await authenticate();
    }
    return _token;
}

function idempotencyKey() {
    return crypto.randomBytes(16).toString('hex'); // 32 hex chars
}

// ── Public API ────────────────────────────────────────────────────────────────

async function cashin(amount, phoneNumber) {
    if (MOCK_MODE) return mockCashin(amount, phoneNumber);

    const token = await getToken();
    return request('/transactions/cashin', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${token}`,
            'X-Idempotency-Key': idempotencyKey(),
        },
        body: JSON.stringify({ amount, number: phoneNumber }),
    });
}

async function cashout(amount, phoneNumber) {
    if (MOCK_MODE) return mockCashin(amount, phoneNumber); // reuse mock

    const token = await getToken();
    return request('/transactions/cashout', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${token}`,
            'X-Idempotency-Key': idempotencyKey(),
        },
        body: JSON.stringify({ amount, number: phoneNumber }),
    });
}

async function getTransaction(ref) {
    if (MOCK_MODE) return mockGetTransaction(ref);

    const token = await getToken();
    return request(`/transactions/find/${ref}`, {
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
    });
}

module.exports = { cashin, cashout, getTransaction };
