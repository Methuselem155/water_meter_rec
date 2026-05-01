/**
 * PM2 Ecosystem — Water Meter Backend
 *
 * Starts all three services with one command:
 *   npm run pm2:start           → start OCR + API + ngrok tunnel
 *   npm run pm2:stop            → stop all
 *   npm run pm2:logs            → tail logs from all services
 *   npm run pm2:status          → show process table
 *   npm run patch-url           → read ngrok URL → patch Flutter constants.dart
 *
 * Prerequisites:
 *   - ngrok installed and authenticated: https://ngrok.com/download
 *     (run once: ngrok config add-authtoken <your-token>)
 *   - pip install anthropic pillow
 */

require('dotenv').config();

const OCR_PORT = process.env.OCR_SERVER_PORT || '5001';
const PYTHON   = process.env.PYTHON_OCR_CMD  || (process.platform === 'win32' ? 'python' : 'python3');

module.exports = {
    apps: [
        // ── 1. Python OCR microservice ─────────────────────────────────────
        {
            name: 'ocr-service',
            interpreter: PYTHON,
            script: 'python_ocr_server.py',
            args: `--port ${OCR_PORT}`,

            // Restart on crash, back off up to 8 s between attempts
            autorestart: true,
            max_restarts: 10,
            restart_delay: 2000,
            exp_backoff_restart_delay: 100,

            // Log files (created automatically under ~/.pm2/logs/ unless overridden)
            out_file: './logs/ocr-service.out.log',
            error_file: './logs/ocr-service.err.log',
            merge_logs: true,
            time: true,

            // Pass every env var from the current shell (including ANTHROPIC_API_KEY)
            env: {
                ...process.env,
                OCR_SERVER_PORT: OCR_PORT,
            },
        },

        // ── 2. Node.js API server ──────────────────────────────────────────
        {
            name: 'api-server',
            script: 'server.js',
            interpreter: 'node',

            autorestart: true,
            max_restarts: 10,
            restart_delay: 2000,
            exp_backoff_restart_delay: 100,

            // Wait for the OCR service to be ready before starting the API
            // (PM2 starts apps in array order — no built-in dependency, but
            //  ocrService.js already falls back to subprocess if the server
            //  is not yet ready, so order is just a courtesy.)
            kill_timeout: 5000,

            out_file: './logs/api-server.out.log',
            error_file: './logs/api-server.err.log',
            merge_logs: true,
            time: true,

            env: {
                ...process.env,
                NODE_ENV: process.env.NODE_ENV || 'development',
                OCR_SERVER_PORT: OCR_PORT,
            },

            // Restart when source files change (dev only — disable in prod)
            watch: false,
        },

        // ── 3. ngrok tunnel → exposes Node API to the internet ────────────
        {
            name: 'ngrok-tunnel',
            script: 'scripts/ngrok-tunnel.js',
            interpreter: 'node',

            autorestart: true,
            max_restarts: 5,
            restart_delay: 3000,

            out_file: './logs/ngrok-tunnel.out.log',
            error_file: './logs/ngrok-tunnel.err.log',
            merge_logs: true,
            time: true,

            env: { ...process.env },
        },
    ],
};
