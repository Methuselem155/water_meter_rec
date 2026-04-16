require('dotenv').config({ override: false });
const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const os = require('os');

const OCR_SERVER_PORT = parseInt(process.env.OCR_SERVER_PORT || '5001', 10);

// Read key dynamically so it's always current (not captured at module load time)
const getApiKey = () => {
    const key = process.env.ANTHROPIC_API_KEY || '';
    if (!key) {
        console.error('[OCR Service] ANTHROPIC_API_KEY is not set — OCR will fail. Check your .env file.');
    }
    return key;
};

const toForwardSlash = (p) => p.replace(/\\/g, '/');

// Path to python_ocr.py — now the single entry point for all OCR via Claude Vision
const PYTHON_OCR_SCRIPT = path.join(__dirname, '..', 'python_ocr.py');


// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Pick the Python executable from env or platform default.
 */
const pythonCmd = () =>
    process.env.PYTHON_OCR_CMD || (os.platform() === 'win32' ? 'python' : 'python3');


/**
 * Normalize a confidence value to 0–1.
 * python_ocr.py already normalizes Claude's 0-100 to 0-1, so this is a safety net.
 */
const normalizeConf = (raw) => {
    const n = parseFloat(raw) || 0;
    return n > 1.0 ? parseFloat((n / 100).toFixed(3)) : parseFloat(n.toFixed(3));
};


/**
 * Spawn python_ocr.py and return the raw parsed JSON from stdout.
 * All OCR modes (display, serial, auto) go through this single function.
 */
const spawnPythonOcrRaw = (imagePath, mode = 'auto') => {
    const cmd = pythonCmd();
    const normalizedPath = toForwardSlash(imagePath);

    console.log(`[OCR Service] Spawning python_ocr.py --mode ${mode}`);

    // 120 s — enough for Claude Vision (60 s) + 2 retries + network overhead
    const SPAWN_TIMEOUT_MS = 120_000;

    return new Promise((resolve, reject) => {
        const proc = spawn(cmd, [PYTHON_OCR_SCRIPT, normalizedPath, '--mode', mode], {
            stdio: ['ignore', 'pipe', 'pipe'],
            env: { ...process.env, ANTHROPIC_API_KEY: getApiKey() },
        });

        let stdout = '';
        let stderr = '';
        let finished = false;

        const timer = setTimeout(() => {
            if (finished) return;
            finished = true;
            proc.kill('SIGTERM');
            reject(new Error(`python_ocr.py timed out after ${SPAWN_TIMEOUT_MS / 1000}s`));
        }, SPAWN_TIMEOUT_MS);

        proc.stdout.on('data', (d) => { stdout += d.toString(); });
        proc.stderr.on('data', (d) => { stderr += d.toString(); });

        proc.on('close', (code) => {
            if (finished) return;
            finished = true;
            clearTimeout(timer);

            if (stderr.trim()) {
                console.warn('[OCR Service][python_ocr stderr]', stderr.trim().slice(0, 400));
            }
            if (code !== 0) {
                return reject(new Error(`python_ocr.py exited with code ${code}. stderr: ${stderr.slice(0, 200)}`));
            }
            try {
                const parsed = JSON.parse(stdout.trim());
                if (parsed.error) return reject(new Error(`python_ocr.py error: ${parsed.error}`));
                resolve(parsed);
            } catch (err) {
                console.error('[OCR Service] Failed to parse python_ocr.py output:', stdout.slice(0, 300));
                reject(new Error(`Failed to parse python_ocr.py JSON: ${err.message}`));
            }
        });

        proc.on('error', (err) => {
            if (finished) return;
            finished = true;
            clearTimeout(timer);
            reject(new Error(`Failed to spawn python_ocr.py: ${err.message}`));
        });
    });
};


// ---------------------------------------------------------------------------
// Public OCR functions
// ---------------------------------------------------------------------------

/**
 * processDisplay(imagePath)
 *
 * Sends the full image to Claude Vision (mode=display) and returns the
 * meter reading fields expected by readingController.js:
 *   { readingValue, integerPart, fractionPart, serialNumberExtracted, confidence, rawText, ocrMethod }
 */
const processDisplay = async (imagePath) => {
    const raw = await spawnPythonOcrRaw(imagePath, 'display');

    const confidence = normalizeConf(raw.confidence ?? 0);

    console.log(
        `[OCR Service][display] integer=${raw.integerPart} fraction=${raw.fractionPart} ` +
        `value=${raw.readingValue} conf=${confidence}`
    );

    return {
        readingValue:          raw.readingValue          ?? null,
        integerPart:           raw.integerPart           || null,
        fractionPart:          raw.fractionPart          || null,
        serialNumberExtracted: raw.serialNumberExtracted ?? null,
        confidence,
        rawText:   raw.rawText  || '',
        ocrMethod: raw.ocrEngine || 'claude-vision',
    };
};


/**
 * processSerial(imagePath)
 *
 * Sends the full image to Claude Vision (mode=serial) and returns the
 * serial number fields expected by readingController.js.
 */
const processSerial = async (imagePath) => {
    const raw = await spawnPythonOcrRaw(imagePath, 'serial');

    const confidence = normalizeConf(raw.confidence ?? 0);

    console.log(
        `[OCR Service][serial] serial=${raw.serialNumberExtracted} conf=${confidence}`
    );

    return {
        readingValue:          null,
        serialNumberExtracted: raw.serialNumberExtracted ?? null,
        confidence,
        rawText:   raw.rawText  || '',
        ocrMethod: raw.ocrEngine || 'claude-vision',
    };
};


// ---------------------------------------------------------------------------
// HTTP server path (used by processImage auto mode)
// ---------------------------------------------------------------------------

/**
 * POST imagePath + mode to the persistent Python OCR HTTP server (python_ocr_server.py).
 */
const callOcrServer = (imagePath, mode = 'auto') => {
    return new Promise((resolve, reject) => {
        const body = JSON.stringify({ imagePath, mode });
        const req = http.request(
            {
                hostname: '127.0.0.1',
                port: OCR_SERVER_PORT,
                path: '/ocr',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(body),
                },
            },
            (res) => {
                let data = '';
                res.on('data', (chunk) => { data += chunk; });
                res.on('end', () => {
                    try {
                        const parsed = JSON.parse(data);
                        if (parsed.error) return reject(new Error(`OCR server: ${parsed.error}`));
                        resolve({
                            readingValue:          parsed.readingValue          ?? null,
                            integerPart:           parsed.integerPart           || null,
                            fractionPart:          parsed.fractionPart          || null,
                            serialNumberExtracted: parsed.serialNumberExtracted ?? null,
                            confidence:            normalizeConf(parsed.confidence ?? 0),
                            rawText:               parsed.rawText || '',
                            ocrMethod:             parsed.ocrEngine || 'claude-vision',
                        });
                    } catch (e) {
                        reject(new Error(`Failed to parse OCR server response: ${e.message}`));
                    }
                });
            }
        );
        req.on('error', reject);
        req.setTimeout(300000, () => req.destroy(new Error('OCR server request timed out')));
        req.write(body);
        req.end();
    });
};


/**
 * Subprocess fallback for auto mode when the HTTP server is unavailable.
 */
const spawnPythonOcr = (imagePath, mode = 'auto') => {
    console.log(`[OCR Service] Fallback subprocess: python_ocr.py --mode ${mode}`);
    return spawnPythonOcrRaw(imagePath, mode).then((parsed) => ({
        readingValue:          parsed.readingValue          ?? null,
        integerPart:           parsed.integerPart           || null,
        fractionPart:          parsed.fractionPart          || null,
        serialNumberExtracted: parsed.serialNumberExtracted ?? null,
        confidence:            normalizeConf(parsed.confidence ?? 0),
        rawText:               parsed.rawText  || '',
        ocrMethod:             parsed.ocrEngine || 'claude-vision',
    }));
};


/**
 * processImage(imagePath, mode)
 *
 * Used by ocrWorker for single full-image uploads.
 * - 'display' → processDisplay  (Claude Vision, display mode)
 * - 'serial'  → processSerial   (Claude Vision, serial mode)
 * - 'auto'    → HTTP server → subprocess fallback (Claude Vision, both fields)
 */
const processImage = async (imagePath, mode = 'auto') => {
    if (!imagePath) throw new Error('Missing imagePath');
    if (mode === 'display') return processDisplay(imagePath);
    if (mode === 'serial')  return processSerial(imagePath);

    // auto mode — try HTTP server first, fall back to subprocess
    try {
        return await callOcrServer(imagePath, mode);
    } catch (serverErr) {
        console.warn(`[OCR Service] Server unavailable (${serverErr.message}), falling back to subprocess`);
        return spawnPythonOcr(imagePath, mode);
    }
};


const terminateWorker = async () => {
    // No persistent worker process to clean up — python_ocr.py is spawned per request
};

module.exports = { processImage, processDisplay, processSerial, terminateWorker };
