"""
Water meter OCR — wires OCR_test/meter_extractor.py to the backend.
Usage: python python_ocr.py <image_path> [--mode auto|display|serial]
"""
import sys, json, re, argparse, os
import cv2
import numpy as np
from PIL import Image, ImageOps

# Add OCR_test to path — do NOT modify anything inside OCR_test
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'OCR_test'))

from meter_extractor import extract_meter_reading
from ocr_extractor import OCREngine

_engine = None

def get_engine():
    global _engine
    if _engine is None:
        _engine = OCREngine(languages=['en'])
    return _engine


def load_image(path):
    pil = ImageOps.exif_transpose(Image.open(path))
    return cv2.cvtColor(np.array(pil.convert('RGB')), cv2.COLOR_RGB2BGR)


def ocr_display(image_path):
    """
    Extract meter reading from a pre-cropped display image.
    Calls extract_meter_reading() from meter_extractor.py exactly as-is.
    Returns the digit string directly — no modification.
    """
    try:
        # meter_extractor.py runs from OCR_test/ directory
        # It needs just the filename if the image is in OCR_test/
        ocr_test_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'OCR_test')
        abs_path = os.path.abspath(image_path)

        if abs_path.startswith(os.path.abspath(ocr_test_dir) + os.sep):
            # Image is inside OCR_test/ — pass just the filename
            lookup_path = os.path.basename(abs_path)
        else:
            # Image is elsewhere — pass full absolute path
            lookup_path = abs_path

        null_path = 'nul' if os.name == 'nt' else '/dev/null'

        # meter_extractor must be run with OCR_test as cwd
        import subprocess, sys
        proc = subprocess.run(
            [sys.executable, 'meter_extractor.py', '--image', lookup_path,
             '--output', null_path],
            capture_output=True, text=True,
            cwd=ocr_test_dir
        )
        # Parse "Final answer: XXXXXXXX" from stdout
        reading = ''
        for line in proc.stdout.splitlines():
            if line.startswith('Final answer:'):
                reading = line.split(':', 1)[1].strip()
                break
        if not reading:
            # fallback: parse READING line
            for line in proc.stdout.splitlines():
                if 'READING:' in line:
                    reading = line.split('READING:', 1)[1].strip()
                    break
    except Exception as e:
        return {
            'readingValue': None,
            'serialNumberExtracted': None,
            'confidence': 0.0,
            'rawText': '',
            'ocrEngine': 'easyocr',
            'success': False,
        }

    # reading is the raw string e.g. "01009578"
    raw_text = re.sub(r'[^0-9?]', '', reading)  # keep digits and ? markers
    clean_text = raw_text.replace('?', '')       # digits only for readingValue

    reading_value = None
    try:
        if clean_text:
            reading_value = int(clean_text)
    except ValueError:
        pass

    return {
        'readingValue': reading_value,
        'serialNumberExtracted': None,
        'confidence': 0.8 if '?' not in raw_text else 0.4,
        'rawText': raw_text,   # exact string from meter_extractor (e.g. "01009578")
        'ocrEngine': 'easyocr',
        'success': bool(clean_text and '?' not in raw_text),
    }


def ocr_serial(image_path):
    """Extract serial number from a pre-cropped serial image."""
    img = load_image(image_path)
    results = get_engine().extract(img)
    serial = None
    for _, text, conf in results:
        cleaned = text.upper().strip().replace('(', 'I').replace('*', '').replace(' ', '')
        for m in re.findall(r'[A-Z0-9]{6,13}', cleaned):
            if re.search(r'[A-Z]', m) and len(re.findall(r'\d', m)) >= 3:
                if len(m) > 8 and m[-1].isalpha() and m[-2].isdigit():
                    m = m[:-1]
                serial = m
                break
        if serial:
            break
    return {
        'readingValue': None,
        'serialNumberExtracted': serial,
        'confidence': 1.0 if serial else 0.0,
        'rawText': serial or '',
        'ocrEngine': 'easyocr',
        'success': bool(serial),
    }


def ocr_auto(image_path):
    """Full image: use meter_extractor for reading, ocr_extractor for serial."""
    display_result = ocr_display(image_path)
    img = load_image(image_path)
    h = img.shape[0]
    # Serial from bottom 40%
    bottom = img[int(h * 0.60):, :]
    serial_result = ocr_serial.__wrapped__(bottom) if hasattr(ocr_serial, '__wrapped__') else None

    # Try serial from full image
    results = get_engine().extract(img)
    serial = None
    for _, text, conf in results:
        cleaned = text.upper().strip().replace('(', 'I').replace('*', '').replace(' ', '')
        for m in re.findall(r'[A-Z0-9]{8,13}', cleaned):
            if re.search(r'[A-Z]', m) and len(re.findall(r'\d', m)) >= 2:
                serial = m; break
        if serial: break

    return {
        'readingValue': display_result['readingValue'],
        'serialNumberExtracted': serial,
        'confidence': display_result['confidence'],
        'rawText': display_result['rawText'],
        'ocrEngine': 'easyocr',
        'success': display_result['success'],
    }


def extract_reading(image_path, mode='auto'):
    if mode == 'display': return ocr_display(image_path)
    if mode == 'serial':  return ocr_serial(image_path)
    return ocr_auto(image_path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('image_path')
    parser.add_argument('--mode', default='auto', choices=['auto', 'display', 'serial'])
    args = parser.parse_args()
    try:
        result = extract_reading(args.image_path, args.mode)
        print(json.dumps(result))
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)


if __name__ == '__main__':
    main()
