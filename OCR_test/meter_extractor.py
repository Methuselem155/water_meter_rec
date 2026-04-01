"""
meter_extractor.py
==================
Meter digit extractor for roller-display meters (white digits on dark background).

Two strategies tried in order:
  1. Merge strategy: EasyOCR left (scale=3) + Tesseract full (scale=2) -> overlap merge
  2. Cell strategy:  EasyOCR full-strip anchor (first 2 digits) + per-cell for rest

Whichever produces a clean expected-length digit string wins.

Usage (CLI):
    python meter_extractor.py --image photo.jpg
    python meter_extractor.py --image photo.jpg --digits 8 --output results.txt

Usage (Python API):
    from meter_extractor import extract_meter_reading
    reading = extract_meter_reading("photo.jpg")
    print(reading)  # e.g. "01001397"
"""

import os
import argparse
import warnings

import cv2
import numpy as np
from PIL import Image

warnings.filterwarnings("ignore")


# ---------------------------------------------------------------------------
# Crop
# ---------------------------------------------------------------------------

def crop_digit_strip(image_path: str) -> np.ndarray:
    """Crop to the dark digit roller strip (rows with mean brightness < 145)."""
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Cannot read image: {image_path}")
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    row_means = np.mean(gray, axis=1)
    dark_rows = np.where(row_means < 145)[0]
    if len(dark_rows) < 5:
        print("[crop] No dark strip found, using full image")
        return gray
    y1, y2 = int(dark_rows[0]), int(dark_rows[-1])
    strip = gray[y1:y2, :]
    print(f"[crop] Strip rows {y1}-{y2}, size {strip.shape[1]}x{strip.shape[0]}")
    return strip


# ---------------------------------------------------------------------------
# Strategy 1: Merge (EasyOCR left + Tesseract right)
# ---------------------------------------------------------------------------

def _merge_overlap(left: str, right: str, expected: int) -> str:
    """Find longest suffix of left that is a prefix of right, merge them.
    Handle cases where Tesseract returns more digits than expected (e.g., 10 for 8-digit meter).
    """
    for overlap in range(min(len(left), len(right)), 0, -1):
        if left.endswith(right[:overlap]):
            merged = left + right[overlap:]
            if len(merged) >= expected:
                return merged[:expected]  # Take first `expected` digits if too long
            else:
                return merged
    combined = left + right
    return combined[:expected] if len(combined) >= expected else combined


def strategy_merge(strip: np.ndarray, reader, expected: int) -> str:
    """
    EasyOCR on full strip at scale=3 (inverted) -> left reading (high-conf, left-side).
    Tesseract on full strip at scale=2 (inverted, psm=8) -> right reading.
    Merge via overlap.
    """
    import pytesseract
    sh, sw = strip.shape

    # EasyOCR scale=3 - take leftmost high-confidence detection
    big3 = cv2.resize(strip, (sw * 3, sh * 3), interpolation=cv2.INTER_CUBIC)
    inv3 = cv2.bitwise_not(big3)
    results = reader.readtext(inv3, detail=1, allowlist="0123456789",
                              text_threshold=0.2, low_text=0.2)
    results.sort(key=lambda r: r[0][0][0])
    easyocr_left = ""
    for bbox, t, c in results:
        if c > 0.8 and bbox[0][0] < sw * 3 * 0.5 and len(t) >= 2:
            easyocr_left = t
            break

    # Tesseract scale=2 psm=8
    big2 = cv2.resize(strip, (sw * 2, sh * 2), interpolation=cv2.INTER_CUBIC)
    inv2 = cv2.bitwise_not(big2)
    pil = Image.fromarray(inv2)
    raw = pytesseract.image_to_string(
        pil, config="--psm 8 -c tessedit_char_whitelist=0123456789"
    ).strip()
    tess_right = "".join(c for c in raw if c.isdigit())

    print(f"[merge] EasyOCR left={easyocr_left!r}, Tesseract right={tess_right!r}")

    if not easyocr_left or not tess_right:
        return ""

    merged = _merge_overlap(easyocr_left, tess_right, expected)
    print(f"[merge] result={merged!r}")
    return merged


# ---------------------------------------------------------------------------
# Strategy 2: Cell-by-cell
# ---------------------------------------------------------------------------

def _read_cell(cell: np.ndarray, reader) -> str:
    """Extract a single digit from a cell. EasyOCR first, Tesseract fallback."""
    import pytesseract
    ch, cw = cell.shape
    if cw < 60:
        pad = (60 - cw) // 2
        cell = cv2.copyMakeBorder(cell, 0, 0, pad, pad, cv2.BORDER_REPLICATE)
        ch, cw = cell.shape
    big = cv2.resize(cell, (cw * 4, ch * 4), interpolation=cv2.INTER_CUBIC)
    inv = cv2.bitwise_not(big)

    try:
        results = reader.readtext(inv, detail=1, allowlist="0123456789",
                                  text_threshold=0.1, low_text=0.1)
        if results:
            best = max(results, key=lambda r: r[2])
            if best[2] > 0.3 and best[1]:
                return best[1][0]
    except Exception:
        pass

    try:
        pil = Image.fromarray(inv)
        raw = pytesseract.image_to_string(
            pil, config="--psm 10 -c tessedit_char_whitelist=0123456789"
        ).strip()
        digits = "".join(c for c in raw if c.isdigit())
        if digits:
            return digits[0]
    except Exception:
        pass

    return "?"


def strategy_cells(strip: np.ndarray, reader, expected: int) -> str:
    """
    EasyOCR full-strip at scale=2 for left anchor + fallback (first 2 digits),
    then per-cell extraction for the remaining digits.
    If cells fail (return '?'), fall back to full-strip EasyOCR reading.
    """
    sh, sw = strip.shape
    cell_w = sw // expected

    # Left anchor from full-strip EasyOCR at scale=2
    big2 = cv2.resize(strip, (sw * 2, sh * 2), interpolation=cv2.INTER_CUBIC)
    inv2 = cv2.bitwise_not(big2)
    results = reader.readtext(inv2, detail=1, allowlist="0123456789",
                              text_threshold=0.2, low_text=0.2)
    results.sort(key=lambda r: r[0][0][0])
    anchor = ""
    full_strip_reading = ""  # Full reading from full-strip EasyOCR for fallback
    for bbox, t, c in results:
        if c > 0.3 and len(t) >= 2:
            anchor = t[:2]
            if not full_strip_reading:
                full_strip_reading = t  # Store full reading as fallback
            print(f"[cells] anchor={t!r} (conf={c:.2f}) -> {anchor!r}")
            break

    digits = list(anchor.ljust(2, "?"))

    # Extract remaining cells, using full-strip reading as fallback for failed cells
    for i in range(2, expected):
        x1 = i * cell_w
        x2 = x1 + cell_w if i < expected - 1 else sw
        cell = strip[:, x1:x2]
        d = _read_cell(cell, reader)
        
        # If cell extraction failed (d == '?'), try fallback from full-strip reading
        if d == "?" and i < len(full_strip_reading):
            d = full_strip_reading[i] if full_strip_reading[i].isdigit() else "?"
            print(f"[cells] cell {i} failed, using fallback from full-strip: {d!r}")
        else:
            print(f"[cells] cell {i}: {d!r}")
        
        digits.append(d)

    result = "".join(digits)[:expected]  # Ensure exactly `expected` digits
    print(f"[cells] result={result!r}")
    return result


# ---------------------------------------------------------------------------
# Main API
# ---------------------------------------------------------------------------

def extract_meter_reading(image_path: str,
                           expected_digits: int = 8,
                           output_path: str = "results.txt") -> str:
    """
    Extract the meter reading from a roller-display meter image.

    Tries merge strategy first, falls back to cell strategy if needed.
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")

    print(f"\n{'='*50}")
    print(f"Processing: {image_path}")
    print(f"{'='*50}")

    import easyocr
    reader = easyocr.Reader(["en"], verbose=False)

    strip = crop_digit_strip(image_path)

    # Try merge strategy first
    reading = strategy_merge(strip, reader, expected_digits)

    # Fall back to cell strategy if merge didn't produce clean result
    # Also check for suspicious patterns: 3+ consecutive zeros (likely Tesseract failure)
    suspicious = len(reading) != expected_digits or "?" in reading
    if not suspicious and len(reading) >= 3:
        # Check for 3+ consecutive zeros anywhere (common Tesseract OCR failure)
        if "000" in reading:
            print("[fallback] merge result has suspicious 000 pattern, trying cell strategy")
            suspicious = True
    
    if suspicious:
        print("[fallback] merge failed, trying cell strategy")
        reading = strategy_cells(strip, reader, expected_digits)

    print(f"\n{'='*50}")
    print(f"READING: {reading}")
    print(f"{'='*50}\n")

    try:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write("=== Meter OCR Results ===\n")
            f.write(f"Image  : {image_path}\n")
            f.write(f"Reading: {reading}\n")
        print(f"Results saved to: {output_path}")
    except Exception as ex:
        print(f"Warning: could not save results: {ex}")

    return reading


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Meter digit extractor",
        epilog=(
            "Examples:\n"
            "  python meter_extractor.py --image photo.jpg\n"
            "  python meter_extractor.py --image photo.jpg --digits 8\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--image", required=True, help="Path to meter image")
    parser.add_argument("--digits", type=int, default=8,
                        help="Expected number of digits (default: 8)")
    parser.add_argument("--output", default="results.txt",
                        help="Output .txt file (default: results.txt)")
    args = parser.parse_args()

    result = extract_meter_reading(
        image_path=args.image,
        expected_digits=args.digits,
        output_path=args.output,
    )
    print(f"Final answer: {result}")
