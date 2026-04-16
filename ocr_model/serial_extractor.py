"""
Serial Number Extractor — dedicated module for extracting meter serial numbers.

Serial numbers follow the pattern: [A-Z][0-9]{2}[A-Z]{2}[0-9]{6}
Example: I20BA008111, I22BA271986

This module imports helpers from ocr_extractor.py and must not modify it.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import pytesseract

from ocr_extractor import (
    _load_image, _blur_score, _get_easy_reader,
    _preprocess_serial_binary, segment_and_read,
)

try:
    import easyocr as _easyocr_mod
    _EASYOCR_AVAILABLE = True
except ImportError:
    _EASYOCR_AVAILABLE = False

logger = logging.getLogger(__name__)

# Serial number pattern: 1 letter, 2 digits, 2 letters, 6 digits (11 chars total)
_SERIAL_PATTERN = re.compile(r"^[A-Z][0-9]{2}[A-Z]{2}[0-9]{6}$")

# Tesseract config for sparse alphanumeric text
_CFG_SERIAL = r"--oem 3 --psm 11 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _validate_pattern(text: str) -> bool:
    """Return True if text matches [A-Z][0-9]{2}[A-Z]{2}[0-9]{6}."""
    return bool(_SERIAL_PATTERN.match(text))


def _apply_substitutions(text: str) -> str:
    """
    Fix common OCR confusions between letters and digits.

    Letter positions (0, 3, 4) must be A-Z:
      digit → letter:  0→O, 1→I, 8→B

    Digit positions (1, 2, 5–10) must be 0-9:
      letter → digit:  O/o/D→0, I/i/l/L→1, Z/z→2, A→4, S/s→5,
                       G/g/b→6, T→7, B→8, q/Q→0

    Also handles 12-char strings by stripping a trailing artefact character,
    and tries all 11-char windows within longer strings.
    """
    LETTER_POS = {0, 3, 4}
    DIGIT_POS  = {1, 2, 5, 6, 7, 8, 9, 10}

    # Map of char → replacement at LETTER positions (must become A-Z)
    LETTER_SUBS = {
        "0": "O",
        "1": "I",
        "8": "B",
    }

    # Map of char → replacement at DIGIT positions (must become 0-9)
    DIGIT_SUBS = {
        "O": "0", "o": "0", "D": "0", "Q": "0", "q": "0",
        "I": "1", "i": "1", "l": "1", "L": "1",
        "Z": "2", "z": "2",
        "A": "4",
        "S": "5", "s": "5",
        "G": "6", "g": "6", "b": "6",
        "T": "7",
        "B": "8",
    }

    # Build candidate strings of length 11 to try
    candidates: list[str] = []
    if len(text) == 11:
        candidates.append(text)
    elif len(text) == 12:
        candidates.append(text[:11])   # strip trailing artefact
        candidates.append(text[1:])    # strip leading artefact
    elif len(text) > 12:
        for start in range(len(text) - 10):
            candidates.append(text[start:start + 11])
    else:
        candidates.append(text)

    for t in candidates:
        if len(t) != 11:
            continue
        # Quick check before substitutions
        if _validate_pattern(t):
            return t

        chars = list(t)
        for pos in range(11):
            ch = chars[pos]
            if pos in LETTER_POS:
                chars[pos] = LETTER_SUBS.get(ch, ch)
            elif pos in DIGIT_POS:
                chars[pos] = DIGIT_SUBS.get(ch, ch)

        substituted = "".join(chars)
        if _validate_pattern(substituted):
            return substituted

    return text


def _localise_serial_region(bgr: np.ndarray) -> tuple[int, int, int, int] | None:
    """
    Attempt to locate the serial number region in the image.

    Strategy:
    1. Run EasyOCR with no allowlist to get all bounding boxes.
    2. Look for detections that contain BOTH letters and digits — the digit
       drums only produce digits, so any mixed alphanumeric detection is the
       serial number (no spatial drum-zone exclusion needed).
    3. If no mixed detection found, fall back to any large text with >= 5 chars.
    4. If still nothing, return None → caller uses full image.
    """
    h, w = bgr.shape[:2]

    try:
        reader = _get_easy_reader()
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        detections = reader.readtext(rgb, detail=1, paragraph=False)
    except Exception as exc:
        logger.debug("EasyOCR localisation failed: %s", exc)
        return None

    # Pass 1: detections with BOTH letters and digits (most reliable serial indicator)
    mixed_qualifying = []
    for bbox, text, conf in detections:
        clean = re.sub(r"[^A-Za-z0-9]", "", text)
        has_letter = any(c.isalpha() for c in clean)
        has_digit  = any(c.isdigit() for c in clean)
        if not (has_letter and has_digit and len(clean) >= 5):
            continue
        xs = [p[0] for p in bbox]
        ys = [p[1] for p in bbox]
        mixed_qualifying.append((int(min(xs)), int(min(ys)), int(max(xs)), int(max(ys))))

    if mixed_qualifying:
        qualifying = mixed_qualifying
    else:
        # Pass 2: any large text ≥ 6 chars (fallback)
        qualifying = []
        for bbox, text, conf in detections:
            if len(re.sub(r"[^A-Za-z0-9]", "", text)) < 6:
                continue
            xs = [p[0] for p in bbox]
            ys = [p[1] for p in bbox]
            bx1, by1 = int(min(xs)), int(min(ys))
            bx2, by2 = int(max(xs)), int(max(ys))
            if (by2 - by1) <= h * 0.03:
                continue
            qualifying.append((bx1, by1, bx2, by2))

    if not qualifying:
        logger.debug("Could not localise serial region; no qualifying detections.")
        return None

    all_x1 = min(q[0] for q in qualifying)
    all_y1 = min(q[1] for q in qualifying)
    all_x2 = max(q[2] for q in qualifying)
    all_y2 = max(q[3] for q in qualifying)

    x1 = max(0, all_x1 - 10)
    y1 = max(0, all_y1 - 20)
    x2 = min(w, all_x2 + 10)
    y2 = min(h, all_y2 + 20)

    return (x1, y1, x2, y2)


def _preprocess_for_serial(bgr: np.ndarray) -> list[np.ndarray]:
    """
    Return multiple preprocessed BGR image variants tuned for low-contrast
    serial number labels (light/grey embossed text on light grid backgrounds).

    Variants tried (in order):
      1. Always upscale to at least 400 px wide so tiny crops get more pixels
      2. CLAHE on grayscale                       – recovers local contrast
      3. Blur → CLAHE                             – suppresses grid/mesh texture first
      4. Adaptive threshold (Gaussian)            – handles uneven lighting
      5. Inverted adaptive threshold              – text lighter than background
      6. Otsu binary                              – global binarise after CLAHE
      7. Inverted Otsu                            – opposite polarity
      8. Sharpen → CLAHE                          – enhance edges before boost
      9. Original (BGR, unprocessed)              – last resort
    """
    variants: list[np.ndarray] = []
    clahe = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(4, 4))

    # --- Upscale to minimum width so small crops have enough pixels for OCR ---
    h, w = bgr.shape[:2]
    min_w = 400
    if w < min_w:
        scale = min_w / w
        bgr = cv2.resize(bgr, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_CUBIC)
        h, w = bgr.shape[:2]

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    # 1. CLAHE only
    enhanced = clahe.apply(gray)
    variants.append(cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR))

    # 2. Gaussian blur → CLAHE  (suppresses fine grid/mesh texture)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    enhanced_blur = clahe.apply(blurred)
    variants.append(cv2.cvtColor(enhanced_blur, cv2.COLOR_GRAY2BGR))

    # 3. Adaptive threshold on blur-enhanced (handles uneven lighting / grid)
    adaptive = cv2.adaptiveThreshold(
        enhanced_blur, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY,
        blockSize=15, C=3,
    )
    variants.append(cv2.cvtColor(adaptive, cv2.COLOR_GRAY2BGR))

    # 4. Inverted adaptive (text lighter than background)
    variants.append(cv2.cvtColor(cv2.bitwise_not(adaptive), cv2.COLOR_GRAY2BGR))

    # 5. Otsu on CLAHE-enhanced
    _, otsu = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    variants.append(cv2.cvtColor(otsu, cv2.COLOR_GRAY2BGR))

    # 6. Inverted Otsu
    variants.append(cv2.cvtColor(cv2.bitwise_not(otsu), cv2.COLOR_GRAY2BGR))

    # 7. Sharpen → CLAHE  (increase edge contrast before enhancement)
    kernel_sharpen = np.array([[-1, -1, -1],
                                [-1,  9, -1],
                                [-1, -1, -1]], dtype=np.float32)
    sharpened = cv2.filter2D(gray, -1, kernel_sharpen)
    sharpened = np.clip(sharpened, 0, 255).astype(np.uint8)
    enhanced_sharp = clahe.apply(sharpened)
    variants.append(cv2.cvtColor(enhanced_sharp, cv2.COLOR_GRAY2BGR))

    # 8. Original unprocessed (last resort)
    variants.append(bgr)

    return variants


def _run_ocr_candidates(bgr_crop: np.ndarray) -> list[tuple[str, float, Any]]:
    """
    Run OCR on the crop across multiple preprocessed image variants.
    Returns a deduplicated list of (text, confidence, bbox) tuples.

    Primary:  EasyOCR across all preprocessing variants.
    Fallback: Tesseract --psm 11 on CLAHE-enhanced grayscale.
    """
    all_candidates: list[tuple[str, float, Any]] = []
    seen: set[str] = set()

    def _add(text: str, conf: float, bbox: Any) -> None:
        clean = re.sub(r"[^A-Z0-9]", "", text.upper())
        if clean and clean not in seen:
            seen.add(clean)
            all_candidates.append((clean, conf, bbox))

    variants = _preprocess_for_serial(bgr_crop)

    if _EASYOCR_AVAILABLE:
        try:
            reader    = _get_easy_reader()
            allowlist = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            for variant in variants:
                rgb = cv2.cvtColor(variant, cv2.COLOR_BGR2RGB)
                try:
                    results = reader.readtext(rgb, allowlist=allowlist,
                                              detail=1, paragraph=False)
                    for bbox, text, conf in results:
                        _add(text, float(conf), bbox)
                except Exception as exc:
                    logger.debug("EasyOCR variant failed: %s", exc)

            if all_candidates:
                return all_candidates
        except Exception as exc:
            logger.warning("EasyOCR unavailable (%s); falling back to Tesseract.", exc)

    # --- Tesseract fallback (run on CLAHE-enhanced gray) ---
    try:
        pytesseract.get_tesseract_version()
    except pytesseract.TesseractNotFoundError:
        raise EnvironmentError(
            "Neither EasyOCR nor Tesseract is available.\n"
            "  Install EasyOCR : pip install easyocr\n"
            "  Install Tesseract: https://github.com/UB-Mannheim/tesseract/wiki"
        )

    # Use the CLAHE-enhanced variant (index 0 from _preprocess_for_serial)
    clahe_variant = variants[0] if variants else bgr_crop
    gray_tess = cv2.cvtColor(clahe_variant, cv2.COLOR_BGR2GRAY)

    try:
        data = pytesseract.image_to_data(
            gray_tess, config=_CFG_SERIAL, output_type=pytesseract.Output.DICT
        )
        for i in range(len(data["text"])):
            token = data["text"][i].strip()
            if not token:
                continue
            try:
                conf = float(data["conf"][i])
            except (ValueError, TypeError):
                conf = 0.0
            conf_norm = max(0.0, min(1.0, conf / 100.0))
            x  = int(data["left"][i])
            y  = int(data["top"][i])
            bw = int(data["width"][i])
            bh = int(data["height"][i])
            bbox = [[x, y], [x + bw, y], [x + bw, y + bh], [x, y + bh]]
            _add(token, conf_norm, bbox)
    except Exception as exc:
        logger.debug("Tesseract OCR failed: %s", exc)

    return all_candidates


# ---------------------------------------------------------------------------
# Main class
# ---------------------------------------------------------------------------

class SerialExtractor:
    """
    Dedicated extractor for meter serial numbers.

    Parameters
    ----------
    blur_threshold : float
        Laplacian-variance cutoff for blur detection. 0 = disabled.
    """

    def __init__(self, blur_threshold: float = 40.0) -> None:
        self.blur_threshold = blur_threshold

    def extract_serial_number(
        self,
        image: str | Path | np.ndarray,
        region_hint: dict | None = None,
        debug_dir: str | Path | None = None,
    ) -> dict[str, Any]:
        """
        Extract the serial number from a meter image using character-by-
        character segmentation.

        Primary: contour-based isolation of each character, with equal-width
        column slicing as fallback.  Secondary: legacy whole-image OCR.

        Parameters
        ----------
        image : str | Path | np.ndarray
            File path, base64 string, or numpy BGR array.
        region_hint : dict | None
            Optional dict with keys x, y, width, height to restrict OCR region.
        debug_dir : str | Path | None
            If set, save annotated segmentation images to this directory.

        Returns
        -------
        dict with keys:
            serial_number : str | None
            confidence    : float
            low_quality   : bool
            bounding_box  : dict | None  — {x, y, width, height} in original coords
        """
        _NUM_CHARS = 11
        _SERIAL_WL = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        bgr = _load_image(image)
        h, w = bgr.shape[:2]

        # Blur / quality assessment
        gray = bgr if bgr.ndim == 2 else cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        blur = _blur_score(gray)
        low_quality = (self.blur_threshold > 0) and (blur < self.blur_threshold)

        null_result: dict[str, Any] = {
            "serial_number": None,
            "confidence": 0.0,
            "low_quality": low_quality,
            "bounding_box": None,
        }

        # Determine crop region
        crop_x1, crop_y1, crop_x2, crop_y2 = 0, 0, w, h

        if region_hint is not None:
            rx = int(region_hint.get("x", 0))
            ry = int(region_hint.get("y", 0))
            rw = int(region_hint.get("width", w))
            rh = int(region_hint.get("height", h))
            cx1 = max(0, rx)
            cy1 = max(0, ry)
            cx2 = min(w, rx + rw)
            cy2 = min(h, ry + rh)
            crop_x1, crop_y1, crop_x2, crop_y2 = cx1, cy1, cx2, cy2
        else:
            region = _localise_serial_region(bgr)
            if region is not None:
                crop_x1, crop_y1, crop_x2, crop_y2 = region
                logger.debug(
                    "Auto-localised serial region: (%d,%d,%d,%d)",
                    crop_x1, crop_y1, crop_x2, crop_y2,
                )

        if crop_x2 <= crop_x1 or crop_y2 <= crop_y1:
            return null_result

        bgr_crop = bgr[crop_y1:crop_y2, crop_x1:crop_x2]

        # ── Primary: proven whole-image OCR (EasyOCR across preprocessing  ────
        # variants).  This is more robust than per-char isolation on real-world
        # serial label images (varying lighting, embossed text, grid backgrounds).
        raw_text   = "?" * _NUM_CHARS
        mean_conf  = 0.0
        bb_list: list[dict] = []

        legacy_candidates = _run_ocr_candidates(bgr_crop)
        logger.debug("Whole-image OCR candidates: %s",
                     [(t, round(c, 3)) for t, c, _ in legacy_candidates])

        for text, conf, bbox in legacy_candidates:
            if _validate_pattern(text):
                raw_text, mean_conf = text, conf
                break
            sub = _apply_substitutions(text)
            if _validate_pattern(sub):
                raw_text, mean_conf = sub, conf
                break

        # Try left-to-right concatenation of all candidates
        if not _validate_pattern(raw_text) and legacy_candidates:
            def _cx(item):
                try:
                    return float(np.mean([p[0] for p in item[2]]))
                except Exception:
                    return 0.0
            sorted_cands = sorted(legacy_candidates, key=_cx)
            combined      = "".join(t for t, _, _ in sorted_cands)
            combined_conf = float(np.mean([c for _, c, _ in sorted_cands]))
            sub = _apply_substitutions(combined)
            if _validate_pattern(sub):
                raw_text, mean_conf = sub, combined_conf

        # ── Secondary: per-char segmentation fills any remaining '?' gaps ─────
        char_result, char_conf, bb_list = segment_and_read(
            bgr_crop,
            num_chars=_NUM_CHARS,
            preprocess_fn=_preprocess_serial_binary,
            whitelist=_SERIAL_WL,
            debug_dir=debug_dir,
            debug_label="serial",
        )
        char_result = _apply_substitutions(char_result)

        # Merge: use whole-image result where valid; fill remaining '?' from
        # per-char where that is more specific.
        if raw_text.count("?") > 0:
            merged = []
            for i in range(_NUM_CHARS):
                wc = raw_text[i] if i < len(raw_text) else "?"
                pc = char_result[i] if i < len(char_result) else "?"
                merged.append(pc if wc == "?" and pc != "?" else wc)
            raw_text = "".join(merged)

        # Ensure exactly 11 characters
        if len(raw_text) < _NUM_CHARS:
            raw_text = raw_text + "?" * (_NUM_CHARS - len(raw_text))
        elif len(raw_text) > _NUM_CHARS:
            raw_text = raw_text[:_NUM_CHARS]

        # Build overall bounding box from per-char boxes
        bounding_box: dict[str, int] | None = None
        if bb_list:
            all_x1 = min(b["x"] for b in bb_list) + crop_x1
            all_y1 = min(b["y"] for b in bb_list) + crop_y1
            all_x2 = max(b["x"] + b["width"] for b in bb_list) + crop_x1
            all_y2 = max(b["y"] + b["height"] for b in bb_list) + crop_y1
            bounding_box = {
                "x": all_x1, "y": all_y1,
                "width": all_x2 - all_x1, "height": all_y2 - all_y1,
            }

        if raw_text.count("?") == _NUM_CHARS:
            return null_result

        return {
            "serial_number": raw_text,
            "confidence": float(mean_conf),
            "low_quality": low_quality,
            "bounding_box": bounding_box,
        }
