const { spawn } = require('child_process');
const path = require('path');
const http = require('http');
const os = require('os');

const OCR_SERVER_PORT = parseInt(process.env.OCR_SERVER_PORT || '5001', 10);

/**
 * POST imagePath + mode to the persistent Python OCR HTTP server.
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
                            readingValue: parsed.readingValue ?? null,
                            serialNumberExtracted: parsed.serialNumberExtracted ?? null,
                            confidence: parsed.confidence ?? null,
                            rawText: parsed.rawText || '',
                            ocrMethod: parsed.ocrEngine || 'easyocr',
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
 * Spawn python_ocr.py as subprocess fallback.
 * Uses OCR_test/ocr_extractor.py pipeline internally via python_ocr.py.
 */
const spawnPythonOcr = (imagePath, mode = 'auto') => {
    const pythonCmd = process.env.PYTHON_OCR_CMD || (os.platform() === 'win32' ? 'python' : 'python3');
    const scriptPath = path.join(__dirname, '..', 'python_ocr.py');

    console.log(`[OCR Service] Spawning subprocess: python_ocr.py --mode ${mode}`);

    return new Promise((resolve, reject) => {
        const proc = spawn(pythonCmd, [scriptPath, imagePath, '--mode', mode], {
            stdio: ['ignore', 'pipe', 'pipe'],
        });

        let stdout = '';
        let stderr = '';

        proc.stdout.on('data', (d) => { stdout += d.toString(); });
        proc.stderr.on('data', (d) => { stderr += d.toString(); });

        proc.on('close', (code) => {
            if (stderr) console.warn('[OCR Service][stderr]', stderr.slice(0, 200));
            if (code !== 0) return reject(new Error(`python_ocr.py exited with code ${code}`));
            try {
                const parsed = JSON.parse(stdout.trim());
                if (parsed.error) return reject(new Error(`python_ocr.py error: ${parsed.error}`));
                resolve({
                    readingValue: parsed.readingValue ?? null,
                    serialNumberExtracted: parsed.serialNumberExtracted ?? null,
                    confidence: parsed.confidence ?? null,
                    rawText: parsed.rawText || '',
                    ocrMethod: parsed.ocrEngine || 'easyocr',
                });
            } catch (err) {
                console.error('[OCR Service] Failed to parse output:', stdout);
                reject(err);
            }
        });
    });
};

/**
 * Process an image with OCR.
 * mode: 'auto' | 'display' | 'serial'
 * - 'display' → image is a crop of the digit display
 * - 'serial'  → image is a crop of the serial number
 * - 'auto'    → full image, detect both regions automatically
 */
const processImage = async (imagePath, mode = 'auto') => {
    if (!imagePath) throw new Error('Missing imagePath');

    try {
        return await callOcrServer(imagePath, mode);
    } catch (serverErr) {
        console.warn(`[OCR Service] Server unavailable (${serverErr.message}), falling back to subprocess`);
        return spawnPythonOcr(imagePath, mode);
    }
};

const terminateWorker = async () => {};

module.exports = { processImage, terminateWorker };
