"""
Persistent OCR HTTP server.
POST /ocr  { "imagePath": "/abs/path/to/image.jpg", "mode": "display|serial|auto" }
GET  /health

Start: python python_ocr_server.py [--port 5001]
"""
import sys, json, argparse, traceback
from http.server import BaseHTTPRequestHandler, HTTPServer

# Import extract_reading from python_ocr.py
from python_ocr import extract_reading, load_image

# Pre-load OCR engine at startup
print('[OCR Server] Loading OCR engine...', flush=True)
from python_ocr import get_engine
get_engine()
print('[OCR Server] Model ready.', flush=True)


class OcrHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress default access log

    def do_GET(self):
        if self.path == '/health':
            self._json(200, {'status': 'ok'})
        else:
            self._json(404, {'error': 'Not found'})

    def do_POST(self):
        if self.path != '/ocr':
            self._json(404, {'error': 'Not found'})
            return

        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)

        try:
            payload = json.loads(body)
            image_path = payload.get('imagePath', '').strip()
            mode = payload.get('mode', 'auto')

            if not image_path:
                self._json(400, {'error': 'Missing imagePath'})
                return

            print(f'[OCR Server] Processing: {image_path} mode={mode}', flush=True)

            if mode == 'serial':
                # Serial mode: load image and run serial extraction
                img = load_image(image_path)
                result = extract_reading(img, 'serial')
            else:
                # Display/auto mode: pass image_path directly so meter_extractor
                # can use its own pipeline (crop_digit_strip etc.)
                result = extract_reading(image_path, mode)

            print(f'[OCR Server] Done: raw={result.get("rawText")} value={result.get("readingValue")}', flush=True)
            self._json(200, result)

        except Exception as e:
            traceback.print_exc()
            self._json(500, {'error': str(e)})

    def _json(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5001)
    args = parser.parse_args()

    server = HTTPServer(('127.0.0.1', args.port), OcrHandler)
    print(f'[OCR Server] Listening on http://127.0.0.1:{args.port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('[OCR Server] Shutting down.')
