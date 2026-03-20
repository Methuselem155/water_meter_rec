const { spawn } = require('child_process');
const path = require('path');

/**
 * Call the Python OCR helper that uses pytesseract.
 * @param {string} imagePath absolute file path
 * @returns {Promise<{readingValue:number|null, serialNumberExtracted:string|null, confidence:number|null, rawText:string}>}
 */
const processImage = async (imagePath) => {
    if (!imagePath) throw new Error('Missing imagePath');

    const pythonCmd = process.env.PYTHON_OCR_CMD || 'python';
    const scriptPath = path.join(__dirname, '..', 'python_ocr.py');

    console.log(`[OCR Service] Invoking Python OCR via ${pythonCmd} ${scriptPath} "${imagePath}"`);

    return new Promise((resolve, reject) => {
        const proc = spawn(pythonCmd, [scriptPath, imagePath], {
            stdio: ['ignore', 'pipe', 'pipe']
        });

        let stdout = '';
        let stderr = '';

        proc.stdout.on('data', (data) => {
            stdout += data.toString();
        });

        proc.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        proc.on('close', (code) => {
            if (stderr) {
                console.warn('[OCR Service][Python stderr]', stderr);
            }

            if (code !== 0) {
                return reject(new Error(`Python OCR exited with code ${code}`));
            }

            try {
                const parsed = JSON.parse(stdout.trim());
                if (parsed.error) {
                    return reject(new Error(`Python OCR error: ${parsed.error}`));
                }

                resolve({
                    readingValue: parsed.readingValue ?? null,
                    serialNumberExtracted: parsed.serialNumberExtracted ?? null,
                    confidence: parsed.confidence ?? null,
                    rawText: parsed.rawText || ''
                });
            } catch (err) {
                console.error('[OCR Service] Failed to parse Python OCR JSON:', err);
                console.error('[OCR Service] Raw stdout:', stdout);
                reject(err);
            }
        });
    });
};

module.exports = {
    processImage
};

