"""
Water meter OCR using Claude Vision API.
Usage: python python_ocr.py <image_path> [--mode auto|display|serial]
"""
import sys, json, re, argparse, os, base64
from pathlib import Path

# Load .env from the project root (same dir as this script)
_env_path = Path(__file__).parent / '.env'
if _env_path.exists():
    for _line in _env_path.read_text().splitlines():
        _line = _line.strip()
        if _line and not _line.startswith('#') and '=' in _line:
            _k, _, _v = _line.partition('=')
            os.environ.setdefault(_k.strip(), _v.strip())

import anthropic

CLAUDE_MODEL = 'claude-sonnet-4-6'

EXTRACTION_PROMPT = (
    "Extract from this water meter image and return ONLY this JSON:\n"
    "{\n"
    '  "full_reading": "01001.39",\n'
    '  "main_digits": "01001",\n'
    '  "decimal_digits": "39",\n'
    '  "unit": "m3",\n'
    '  "serial_number": "I20BA008111",\n'
    '  "brand": "Itron",\n'
    '  "confidence": 92,\n'
    '  "notes": ""\n'
    "}\n"
    "Black/dark background = main digits. Red/pink background = decimal digits."
)


def _encode_image(image_path):
    """Read image file, compress if needed, and return (base64_string, media_type)."""
    MAX_BYTES = 4 * 1024 * 1024  # 4 MB — stay safely under Claude's 5 MB limit

    with open(image_path, 'rb') as f:
        data = f.read()

    ext = os.path.splitext(image_path)[1].lower()
    media_types = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.webp': 'image/webp',
        '.gif': 'image/gif',
    }
    media_type = media_types.get(ext, 'image/jpeg')

    if len(data) > MAX_BYTES:
        try:
            from PIL import Image as PILImage
            import io
            img = PILImage.open(image_path).convert('RGB')
            quality = 85
            while quality >= 40:
                buf = io.BytesIO()
                img.save(buf, format='JPEG', quality=quality)
                buf.seek(0)
                data = buf.read()
                if len(data) <= MAX_BYTES:
                    break
                quality -= 10
            media_type = 'image/jpeg'
        except ImportError:
            pass  # Pillow not available, send as-is and let Claude reject if too large

    return base64.standard_b64encode(data).decode('utf-8'), media_type


def _call_claude(image_path):
    """Send the full image to Claude Vision and return the parsed JSON dict."""
    b64_data, media_type = _encode_image(image_path)

    client = anthropic.Anthropic(
        api_key=os.environ.get('ANTHROPIC_API_KEY'),
        timeout=60.0,
        max_retries=2,
    )

    message = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=512,
        messages=[
            {
                'role': 'user',
                'content': [
                    {
                        'type': 'image',
                        'source': {
                            'type': 'base64',
                            'media_type': media_type,
                            'data': b64_data,
                        },
                    },
                    {
                        'type': 'text',
                        'text': EXTRACTION_PROMPT,
                    },
                ],
            }
        ],
    )

    text = message.content[0].text.strip()

    # Strip markdown code fences if Claude wraps the JSON in ```
    text = re.sub(r'^```(?:json)?\s*', '', text)
    text = re.sub(r'\s*```$', '', text)

    return json.loads(text.strip())


def ocr_display(image_path):
    """Extract meter reading via Claude Vision. Returns backend-compatible dict."""
    try:
        data = _call_claude(image_path)

        main_digits    = data.get('main_digits', '') or ''
        decimal_digits = data.get('decimal_digits', '') or ''
        full_reading   = data.get('full_reading', '') or ''
        # Claude returns confidence 0-100; normalize to 0-1
        confidence     = round(float(data.get('confidence', 0)) / 100.0, 3)

        reading_value = None
        if full_reading:
            try:
                reading_value = float(full_reading)
            except ValueError:
                pass

        return {
            'integer_reading':        main_digits    or None,
            'decimal_reading':        decimal_digits or None,
            'decimal_estimated':      False,
            'readingValue':           reading_value,
            'integerPart':            main_digits    or None,
            'fractionPart':           decimal_digits or None,
            'serialNumberExtracted':  data.get('serial_number') or None,
            'confidence':             confidence,
            'rawText':                full_reading,
            'ocrEngine':              'claude-vision',
            'success':                bool(main_digits),
        }

    except Exception as e:
        print(f'[ocr_display] Error: {e}', file=sys.stderr)
        return {
            'integer_reading':        None,
            'decimal_reading':        None,
            'decimal_estimated':      False,
            'readingValue':           None,
            'integerPart':            None,
            'fractionPart':           None,
            'serialNumberExtracted':  None,
            'confidence':             0.0,
            'rawText':                '',
            'ocrEngine':              'claude-vision',
            'success':                False,
        }


def ocr_serial(image_path):
    """Extract serial number via Claude Vision. Returns backend-compatible dict."""
    try:
        data = _call_claude(image_path)

        serial     = data.get('serial_number') or None
        confidence = round(float(data.get('confidence', 0)) / 100.0, 3)

        return {
            'readingValue':           None,
            'serialNumberExtracted':  serial,
            'confidence':             confidence,
            'rawText':                serial or '',
            'ocrEngine':              'claude-vision',
            'success':                bool(serial),
        }

    except Exception as e:
        print(f'[ocr_serial] Error: {e}', file=sys.stderr)
        return {
            'readingValue':           None,
            'serialNumberExtracted':  None,
            'confidence':             0.0,
            'rawText':                '',
            'ocrEngine':              'claude-vision',
            'success':                False,
        }


def ocr_auto(image_path):
    """Extract both reading and serial number via Claude Vision in a single API call."""
    try:
        data = _call_claude(image_path)

        main_digits    = data.get('main_digits', '') or ''
        decimal_digits = data.get('decimal_digits', '') or ''
        full_reading   = data.get('full_reading', '') or ''
        serial         = data.get('serial_number') or None
        confidence     = round(float(data.get('confidence', 0)) / 100.0, 3)

        reading_value = None
        if full_reading:
            try:
                reading_value = float(full_reading)
            except ValueError:
                pass

        return {
            'readingValue':           reading_value,
            'integerPart':            main_digits    or None,
            'fractionPart':           decimal_digits or None,
            'serialNumberExtracted':  serial,
            'confidence':             confidence,
            'rawText':                full_reading,
            'ocrEngine':              'claude-vision',
            'success':                bool(main_digits),
        }

    except Exception as e:
        print(f'[ocr_auto] Error: {e}', file=sys.stderr)
        return {
            'readingValue':           None,
            'integerPart':            None,
            'fractionPart':           None,
            'serialNumberExtracted':  None,
            'confidence':             0.0,
            'rawText':                '',
            'ocrEngine':              'claude-vision',
            'success':                False,
        }


def extract_reading(image_path, mode='auto'):
    if mode == 'display':
        return ocr_display(image_path)
    if mode == 'serial':
        return ocr_serial(image_path)
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
