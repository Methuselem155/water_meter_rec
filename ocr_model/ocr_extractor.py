"""
OCR Extractor — core reusable class.

Preprocessing pipeline
----------------------
1. Grayscale conversion  : colour channels are irrelevant for OCR; removing them
                           reduces noise and speeds every downstream step.
2. Upscaling (tiny only) : Only images with a short side < 100 px are upscaled 2×.
                           Upscaling larger images introduces interpolation artefacts
                           that hurt accuracy on photos.
3. Contrast normalisation: CLAHE locally boosts contrast so faint text on uneven
                           backgrounds becomes visible.
4. Denoising (doc only)  : fastNlMeansDenoising is applied ONLY for document / scan
                           images.  For photos the denoiser blurs digit strokes and
                           consistently makes results worse.
5. Deskewing             : Hough-line voting detects skew.  Correction is capped at
                           ±10° — larger angles are mis-detections (portrait photos,
                           tilted cameras) not real text skew.
6. Thresholding (doc)    : Otsu's global threshold binarises scan / line-art images.
                           Photo-like images are fed as enhanced greyscale to Tesseract.
7. Morphological opening : 2×2 kernel removes 1-2 px specks after binarisation.

Meter mode
----------
The meter has two zones separated by background colour:
  • Integer part  : 5 digits on a BLACK background  (dark zone)
  • Fraction part : 3 digits on a COLOURED background (light zone, e.g. red)

`extract_meter_reading()` automatically finds the dark/light boundary, runs OCR on
each zone independently, then returns `integer_part`, `fraction_part`, and the
combined `reading` formatted as "XXXXX.XXX".
"""

from __future__ import annotations

import base64
import logging
import re
from pathlib import Path
from typing import Any

import cv2

# New ground-up engine (imported lazily to avoid circular imports at module load)
try:
    from meter_ocr_engine import MeterOCREngine as _MeterOCREngine
    _NEW_ENGINE_AVAILABLE = True
except ImportError:
    _NEW_ENGINE_AVAILABLE = False

import numpy as np
import pytesseract


# EasyOCR is optional — imported lazily so the module works without it
try:
    import easyocr as _easyocr_mod
    _EASYOCR_AVAILABLE = True
except ImportError:
    _EASYOCR_AVAILABLE = False

logger = logging.getLogger(__name__)

# Shared EasyOCR reader (initialised once on first use — heavyweight to create)
_easy_reader: Any = None


def _get_easy_reader():
    """Return a cached EasyOCR Reader (English, CPU)."""
    global _easy_reader
    if _easy_reader is None:
        if not _EASYOCR_AVAILABLE:
            raise RuntimeError(
                "EasyOCR is not installed. Run: pip install easyocr"
            )
        logger.debug("Initialising EasyOCR reader (first call may take ~10 s)…")
        _easy_reader = _easyocr_mod.Reader(["en"], gpu=False, verbose=False)
    return _easy_reader

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SUPPORTED_FORMATS = {".png", ".jpg", ".jpeg", ".bmp", ".tiff", ".tif", ".webp"}

# OEM 3 = LSTM engine; PSM 6 = uniform block; PSM 7 = single line; PSM 11 = sparse text
_CFG_BLOCK       = r"--oem 3 --psm 6"
_CFG_LINE        = r"--oem 3 --psm 7"
_CFG_DIGITS      = r"--oem 3 --psm 7 -c tessedit_char_whitelist=0123456789"
_CFG_DIGITS_BLK  = r"--oem 3 --psm 6 -c tessedit_char_whitelist=0123456789"
_CFG_DIGITS_SPRS = r"--oem 3 --psm 11 -c tessedit_char_whitelist=0123456789"

# Vertical crop: use the middle 60 % of image height to avoid borders
_CROP_TOP_FRAC    = 0.20
_CROP_BOTTOM_FRAC = 0.20

# Dark-background threshold (V channel in HSV): pixels darker than this belong
# to the "black background" (integer) zone
_DARK_V_THRESHOLD = 80

# Minimum number of dark-bg columns to consider a zone "valid"
_MIN_DARK_COLS = 20


# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------

def _load_image(source: str | Path | np.ndarray) -> np.ndarray:
    """Accept file path, base64 string, or numpy array → BGR ndarray."""
    if isinstance(source, np.ndarray):
        return source.copy()

    source = str(source)

    # Detect base64: long string with few path separators
    if "\n" not in source and len(source) > 260 and source.count("/") < 3:
        try:
            arr = np.frombuffer(base64.b64decode(source), dtype=np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if img is not None:
                return img
        except Exception:
            pass

    path = Path(source)
    if not path.exists():
        raise FileNotFoundError(f"Image not found: {path}")
    suffix = path.suffix.lower()
    if suffix not in SUPPORTED_FORMATS:
        raise ValueError(
            f"Unsupported format '{suffix}'. "
            f"Supported: {', '.join(sorted(SUPPORTED_FORMATS))}"
        )
    img = cv2.imread(str(path))
    if img is None:
        raise ValueError(f"OpenCV could not decode: {path}")
    return img


def _is_document_like(gray: np.ndarray) -> bool:
    """
    True when the image histogram is bimodal (dark ink + light paper).
    Photo-like images have a wide midtone spread → False.
    """
    hist  = cv2.calcHist([gray], [0], None, [256], [0, 256]).flatten()
    dark  = float(hist[:64].sum())
    light = float(hist[192:].sum())
    total = float(gray.size)
    return (dark + light) / total > 0.85


def _blur_score(gray: np.ndarray) -> float:
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def _deskew(gray: np.ndarray) -> np.ndarray:
    """
    Correct skew using Hough-line voting, capped at ±10°.
    Angles larger than 10° are almost certainly not text skew.
    """
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLines(edges, 1, np.pi / 180, threshold=100)
    if lines is None:
        return gray

    angles = []
    for line in lines[:50]:
        rho, theta = line[0]
        deg = np.degrees(theta) - 90.0
        if abs(deg) <= 10.0:
            angles.append(deg)

    if not angles:
        return gray

    skew = float(np.median(angles))
    if abs(skew) < 0.5:
        return gray

    logger.debug("Deskewing %.2f°", skew)
    h, w = gray.shape
    M = cv2.getRotationMatrix2D((w // 2, h // 2), skew, 1.0)
    return cv2.warpAffine(gray, M, (w, h),
                          flags=cv2.INTER_CUBIC,
                          borderMode=cv2.BORDER_REPLICATE)


def _best_ocr(
    images: np.ndarray | list[np.ndarray],
    configs: list[str],
) -> tuple[str, float]:
    """
    Try every (image, config) combination and return (text, mean_conf) for
    the run with the highest mean confidence (among runs that produced at
    least one alphanumeric character).  Ties are broken by character count.

    Pass a list of images to let the function pick the best preprocessing
    variant automatically (e.g. raw gray vs CLAHE-enhanced).
    """
    if isinstance(images, np.ndarray):
        images = [images]

    best_text = ""
    best_conf = -1.0
    best_len  = 0

    for img in images:
        for cfg in configs:
            try:
                data  = pytesseract.image_to_data(img, config=cfg,
                                                   output_type=pytesseract.Output.DICT)
                tokens = [t.strip() for t in data["text"]]
                confs  = []
                chars  = []
                for t, c in zip(tokens, data["conf"]):
                    if not t:
                        continue
                    try:
                        cf = float(c)
                    except (ValueError, TypeError):
                        cf = -1.0
                    if cf >= 0:
                        confs.append(cf)
                        chars.append(t)
                text  = " ".join(chars).strip()
                pos   = [c for c in confs if c > 0]
                mc    = round(float(np.mean(pos)), 2) if pos else 0.0
                alnum = len(re.sub(r"[^A-Za-z0-9]", "", text))
                # Prefer higher confidence; break ties with character count
                if alnum > 0 and (mc > best_conf or (mc == best_conf and alnum > best_len)):
                    best_text, best_conf, best_len = text, mc, alnum
            except Exception as exc:
                logger.debug("OCR img/config '%s' failed: %s", cfg, exc)

    return best_text, max(best_conf, 0.0)


def _ocr_bounding_boxes(
    gray: np.ndarray,
    config: str,
    threshold: float,
    x_offset: int = 0,
    y_offset: int = 0,
) -> list[dict]:
    """
    Return word-level bounding boxes from image_to_data.
    x_offset / y_offset shift coordinates back into the original image space.
    """
    data  = pytesseract.image_to_data(gray, config=config,
                                       output_type=pytesseract.Output.DICT)
    boxes = []
    for i in range(len(data["text"])):
        token = data["text"][i].strip()
        if not token:
            continue
        try:
            conf = float(data["conf"][i])
        except (ValueError, TypeError):
            conf = -1.0
        if conf < 0:
            continue
        if conf > 0 and conf < threshold:
            continue
        boxes.append({
            "char":       token,
            "x":          int(data["left"][i])  + x_offset,
            "y":          int(data["top"][i])   + y_offset,
            "width":      int(data["width"][i]),
            "height":     int(data["height"][i]),
            "confidence": round(conf, 2),
        })
    return boxes


# ---------------------------------------------------------------------------
# Meter-specific helpers
# ---------------------------------------------------------------------------

def _find_dark_boundary(bgr: np.ndarray) -> int:
    """
    Find the x-coordinate separating the integer zone (left, 5 digits) from
    the fraction zone (right, 3 digits).

    Strategy
    --------
    1. Start with the positional fallback: x = 5/8 of image width.
       For pre-cropped meter display images this is always correct.
    2. Refine using hue-shift detection: if the median hue right of the
       5/8 position differs from the left baseline by > 30°, snap to the
       first column where that sustained shift begins (run of ≥ 10 cols).
    3. Validate the result lies in the 40–80% width range; otherwise
       return -1 so the caller uses the 5/8 fallback.
    """
    h, w = bgr.shape[:2]

    # Positional prior — always reliable for pre-cropped 8-digit displays
    positional = int(w * 5 / 8)

    # Crop central 40% height for hue analysis
    y1   = int(h * 0.30)
    y2   = int(h * 0.70)
    crop = bgr[y1:y2, :]

    hsv  = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
    col_h = np.median(hsv[:,:,0], axis=0).astype(float)
    col_s = np.median(hsv[:,:,1], axis=0).astype(float)

    # Baseline hue = left 25% of columns (always integer zone)
    baseline_h = float(np.median(col_h[:max(1, w // 4)]))

    # Check if there is a meaningful hue shift right of the positional split
    right_hue = float(np.median(col_h[positional:]))
    global_diff = abs(right_hue - baseline_h)
    global_diff = min(global_diff, 180 - global_diff)

    if global_diff < 30:
        # No meaningful colour boundary — use positional split directly
        logger.debug(
            "No colour boundary detected (global_diff=%.1f°); using positional split x=%d",
            global_diff, positional,
        )
        return positional

    # Hue boundary exists — find where it starts (run of ≥ 10 cols with diff > 30°)
    HUE_JUMP = 30.0
    RUN_MIN  = 10
    hue_boundary = -1
    run = 0
    for x in range(w // 4, int(w * 0.90)):
        diff = abs(float(col_h[x]) - baseline_h)
        diff = min(diff, 180 - diff)
        if diff > HUE_JUMP:
            if run == 0:
                hue_boundary = x
            run += 1
            if run >= RUN_MIN:
                break
        else:
            run = 0
            hue_boundary = -1
    if run < RUN_MIN:
        hue_boundary = -1

    # Validate: must lie in 40–80% of width
    if hue_boundary < int(w * 0.40) or hue_boundary > int(w * 0.80):
        logger.debug(
            "Hue boundary %d outside valid range; using positional split x=%d",
            hue_boundary, positional,
        )
        return positional

    # Snap to nearest low-saturation column (digit separator gap)
    search_lo = max(0,   hue_boundary - 30)
    search_hi = min(w-1, hue_boundary + 30)
    snap_x    = int(np.argmin(col_s[search_lo:search_hi])) + search_lo
    if abs(snap_x - hue_boundary) < 30:
        hue_boundary = snap_x

    logger.debug(
        "Colour boundary at x=%d (global_diff=%.1f°, image_w=%d)",
        hue_boundary, global_diff, w,
    )
    return hue_boundary


def _clean_digits(text: str) -> str:
    """Keep only digit characters."""
    return re.sub(r"[^0-9]", "", text)


def _pad_digits(digits: str, length: int) -> str:
    """Zero-pad on the left to exactly `length` digits."""
    return digits.zfill(length)[:length]


def _digit_row_crop(bgr: np.ndarray, margin: int = 15) -> tuple[int, int]:
    """
    Find the y-range of the digit row using horizontal edge energy.
    Returns (y1, y2) with a small margin added.
    """
    h = bgr.shape[0]
    gray   = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    row_e  = np.mean(np.abs(sobely), axis=1)
    smooth = np.convolve(row_e, np.ones(20) / 20, mode="same")
    thresh = smooth.max() * 0.30
    rows   = np.where(smooth > thresh)[0]
    if len(rows) == 0:
        return 0, h
    return max(0, int(rows[0]) - margin), min(h, int(rows[-1]) + margin)


def _best_digit_string_from_detections(
    detections: list[tuple],
    target_len: int,
    conf_min: float = 0.1,
) -> tuple[str, float]:
    """
    Given EasyOCR detections (each: (bbox, text, conf)), pick the best
    digit string of exactly `target_len` characters.

    Priority
    --------
    1. Exact-length digit strings at conf ≥ conf_min — highest conf wins.
    2. Among strings shorter than target_len — longest then highest conf.
    3. Among strings longer — take the first target_len chars of highest conf.
    4. Fall back to concatenating all detections sorted left→right.
    """
    exact, shorter, longer = [], [], []
    for bbox, text, conf in detections:
        if conf < conf_min:
            continue
        d = _clean_digits(text)
        if not d:
            continue
        cx = float(np.mean([p[0] for p in bbox]))
        if len(d) == target_len:
            exact.append((d, conf, cx))
        elif len(d) < target_len:
            shorter.append((d, conf, cx))
        else:
            longer.append((d, conf, cx))

    if exact:
        best = max(exact, key=lambda x: x[1])
        return best[0], best[1]

    if shorter:
        best = max(shorter, key=lambda x: (len(x[0]), x[1]))
        return _pad_digits(best[0], target_len), best[1]

    if longer:
        best = max(longer, key=lambda x: x[1])
        return best[0][:target_len], best[1]

    # Last resort: concatenate left-to-right, zero-pad / truncate
    all_det = [(cx, d, c) for (d, c, cx) in shorter + exact + longer]  # already exhausted; recompute
    all_det2 = []
    for bbox, text, conf in detections:
        d = _clean_digits(text)
        if d:
            cx = float(np.mean([p[0] for p in bbox]))
            all_det2.append((cx, d, conf))
    all_det2.sort(key=lambda x: x[0])
    combined = "".join(d for _, d, _ in all_det2)
    if combined:
        return _pad_digits(_clean_digits(combined), target_len), 0.0

    return "?" * target_len, 0.0


def _enhance_zone(bgr_zone: np.ndarray) -> np.ndarray:
    """
    Apply CLAHE contrast enhancement to a BGR zone image.
    Works in LAB colour space so colour is preserved while luminance is enhanced.
    """
    if bgr_zone.size == 0:
        return bgr_zone
    lab = cv2.cvtColor(bgr_zone, cv2.COLOR_BGR2LAB)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)


# ---------------------------------------------------------------------------
# Character-by-character segmentation pipeline
# ---------------------------------------------------------------------------

def _preprocess_meter_binary(bgr: np.ndarray) -> np.ndarray:
    """
    Binarise a meter display crop.

    Meter displays have two background zones (dark integer + coloured fraction)
    so plain Otsu often picks a threshold that fails on one zone.  We run both
    Otsu and adaptive threshold after CLAHE enhancement, pick the result whose
    foreground density is closest to 40% (typical for digit crops), then apply
    morphological close/open to fill stroke gaps and remove speck noise.

    Returns: white foreground on black background.
    """
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY) if bgr.ndim == 3 else bgr.copy()

    # CLAHE to equalise contrast across the dual-background zones
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
    enhanced = clahe.apply(gray)

    # Candidate 1: Otsu on CLAHE-enhanced
    _, binary_otsu = cv2.threshold(enhanced, 0, 255,
                                   cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Candidate 2: adaptive threshold (handles uneven per-zone illumination)
    binary_adapt = cv2.adaptiveThreshold(
        enhanced, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, blockSize=25, C=-5,
    )

    # Pick the candidate whose foreground density is closest to 40 %
    target_density = 0.40
    for binary in (binary_otsu, binary_adapt):
        if np.mean(binary) > 127:
            binary = cv2.bitwise_not(binary)
        # After inversion, foreground = white (255)

    def _density(b):
        inverted = b if np.mean(b) <= 127 else cv2.bitwise_not(b)
        return float(np.mean(inverted > 0))

    binary = (binary_otsu
              if abs(_density(binary_otsu) - target_density)
              <= abs(_density(binary_adapt) - target_density)
              else binary_adapt)

    # Ensure white = foreground
    if np.mean(binary) > 127:
        binary = cv2.bitwise_not(binary)

    # Morphological close: fill gaps in broken digit strokes (vertical first)
    k_close = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 3))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, k_close)

    # Morphological open: remove single-pixel noise specks
    k_open = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, k_open)

    return binary


def _preprocess_serial_binary(bgr: np.ndarray) -> np.ndarray:
    """CLAHE + adaptive threshold for serial labels (dark text on white bg)."""
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY) if bgr.ndim == 3 else bgr.copy()
    clahe = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(4, 4))
    enhanced = clahe.apply(gray)
    # BINARY_INV: dark text → white foreground on black background
    binary = cv2.adaptiveThreshold(
        enhanced, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV, blockSize=15, C=3,
    )
    return binary


def _find_char_contours(
    binary: np.ndarray,
    min_h_ratio: float = 0.30,
    max_h_ratio: float = 0.95,
    expected_num: int | None = None,
) -> list[tuple[int, int, int, int]]:
    """
    Find character-sized contour bounding boxes, sorted left-to-right.
    Expects white foreground on black background.

    Parameters
    ----------
    binary       : white-on-black binary image (already cropped to digit row)
    min_h_ratio  : contours shorter than this fraction of image height are noise
    max_h_ratio  : contours taller than this fraction are borders/frames
    expected_num : if provided, enables width-based filtering and splitting:
                   - contours narrower than 30% of expected digit width → noise
                   - contours wider than 160% of expected digit width → split
                     into the appropriate number of equal sub-columns

    Returns list of (x, y, w, h) tuples.
    """
    h_img, w_img = binary.shape[:2]
    expected_w = (w_img / expected_num) if expected_num else None
    min_w_abs = max(3, int(expected_w * 0.30)) if expected_w else 3

    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    boxes: list[tuple[int, int, int, int]] = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        # Height filter — remove labels, borders, tiny noise
        if h < h_img * min_h_ratio or h > h_img * max_h_ratio:
            continue
        # Minimum width filter
        if w < min_w_abs:
            continue
        # If this contour spans multiple expected digit widths, split it
        if expected_w and w > expected_w * 1.6:
            n_splits = max(2, round(w / expected_w))
            sw = w // n_splits
            for i in range(n_splits):
                boxes.append((x + i * sw, y, sw, h))
        else:
            boxes.append((x, y, w, h))

    boxes.sort(key=lambda b: b[0])

    # Merge only strongly overlapping boxes (broken strokes of the same char).
    # Overlap must be > 50 % of the narrower box — prevents merging adjacent digits.
    merged: list[tuple[int, int, int, int]] = []
    for box in boxes:
        if merged:
            px, py, pw, ph = merged[-1]
            bx, by, bw, bh = box
            overlap = (px + pw) - bx
            smaller_w = min(pw, bw)
            if overlap > 0 and overlap >= smaller_w * 0.5:
                nx = min(px, bx)
                ny = min(py, by)
                nx2 = max(px + pw, bx + bw)
                ny2 = max(py + ph, by + bh)
                merged[-1] = (nx, ny, nx2 - nx, ny2 - ny)
                continue
        merged.append(box)

    return merged


def _equal_width_slices(
    w_img: int, h_img: int, num_chars: int,
) -> list[tuple[int, int, int, int]]:
    """Fallback: split image into num_chars equal-width vertical columns."""
    col_w = w_img // num_chars
    return [(i * col_w, 0, col_w, h_img) for i in range(num_chars)]


def _recognize_char(
    bgr_roi: np.ndarray,
    whitelist: str,
) -> tuple[str, float]:
    """
    Recognise a single isolated character from a BGR colour ROI.

    Receiving the original colour crop (not a pre-binarised ROI) is critical:
    the global binary used for segmentation can distort thin strokes and
    mis-threshold coloured backgrounds (e.g. the red fraction zone on a meter).

    Strategy
    --------
    1. Scale the ROI to a standard 64-px height — guarantees OCR resolution.
    2. Generate 6 preprocessing variants (CLAHE enhanced, Otsu, adaptive,
       and their inverses) so at least one suits the local background colour.
    3. Pad each variant with 20 px white border (Tesseract PSM 10/13/7 need
       context around the glyph).
    4. Try Tesseract PSM 10 → 13 → 7 on every variant, keep highest confidence.
    5. If best confidence < 0.5, try EasyOCR on the colour-scaled crop.

    Returns (char, confidence 0–1).
    """
    TARGET_H = 64
    PAD = 20
    wl_set = set(whitelist)

    h_roi, w_roi = bgr_roi.shape[:2]
    if h_roi < 4 or w_roi < 2:
        return "?", 0.0

    # Scale ROI to TARGET_H height, preserving the natural aspect ratio.
    # Then PAD the sides if the result is narrower than MIN_W.
    #
    # Critical distinction: we PAD rather than STRETCH.  Stretching a narrow
    # digit like '1' (natural width ~15 px) to 40 px changes its shape so
    # dramatically that every OCR engine misreads it.  Padding keeps the true
    # glyph shape and only adds neutral white space around it.
    MIN_W = 40
    scale_h = TARGET_H / h_roi
    natural_w = max(4, int(w_roi * scale_h))
    bgr_scaled = cv2.resize(bgr_roi, (natural_w, TARGET_H),
                            interpolation=cv2.INTER_CUBIC)
    if natural_w < MIN_W:
        pad_total = MIN_W - natural_w
        pad_l, pad_r = pad_total // 2, pad_total - pad_total // 2
        bgr_scaled = cv2.copyMakeBorder(
            bgr_scaled, 0, 0, pad_l, pad_r,
            cv2.BORDER_CONSTANT, value=(255, 255, 255),
        )

    gray = cv2.cvtColor(bgr_scaled, cv2.COLOR_BGR2GRAY)

    # Individual colour channels.
    # For white digits on a red/coloured background the BLUE channel gives
    # far better contrast than grayscale:
    #   white digit  → B ≈ 240   (bright)
    #   red bg       → B ≈ 30    (very dark)
    # This is the primary fix for '1' (and '2','5') on the coloured zone.
    b_ch = bgr_scaled[:, :, 0]   # BGR order: 0 = Blue
    g_ch = bgr_scaled[:, :, 1]   # 1 = Green

    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(2, 4))
    enhanced = clahe.apply(gray)
    _, otsu   = cv2.threshold(enhanced, 0, 255,
                              cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    adapt = cv2.adaptiveThreshold(
        enhanced, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, blockSize=11, C=2,
    )
    # Fixed thresholds span the full brightness range so at least one
    # matches whatever background colour the character sits on.
    _, fixed80  = cv2.threshold(enhanced,  80, 255, cv2.THRESH_BINARY)
    _, fixed128 = cv2.threshold(enhanced, 128, 255, cv2.THRESH_BINARY)
    _, fixed160 = cv2.threshold(enhanced, 160, 255, cv2.THRESH_BINARY)
    _, fixed200 = cv2.threshold(enhanced, 200, 255, cv2.THRESH_BINARY)

    def _dark_on_white(img: np.ndarray) -> np.ndarray:
        """Ensure dark text on white background (Tesseract convention)."""
        return img if np.mean(img) > 127 else cv2.bitwise_not(img)

    def _binarize_channel(ch: np.ndarray) -> np.ndarray:
        """CLAHE + Otsu on a single colour channel → dark-on-white."""
        enh = clahe.apply(ch)
        _, o = cv2.threshold(enh, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return _dark_on_white(o)

    variants = [
        # --- colour-channel binarisations (best for coloured-bg digits) ---
        _binarize_channel(b_ch),          # blue ch: white-on-red → black-on-white
        _binarize_channel(g_ch),          # green ch
        # --- standard grayscale variants ---
        _dark_on_white(otsu),
        _dark_on_white(cv2.bitwise_not(otsu)),
        _dark_on_white(adapt),
        _dark_on_white(cv2.bitwise_not(adapt)),
        _dark_on_white(fixed80),
        _dark_on_white(fixed128),
        _dark_on_white(fixed160),
        _dark_on_white(fixed200),
        _dark_on_white(enhanced),
        _dark_on_white(gray),
    ]

    best_char, best_conf = "?", 0.0

    for img_variant in variants:
        padded = cv2.copyMakeBorder(
            img_variant, PAD, PAD, PAD, PAD, cv2.BORDER_CONSTANT, value=255,
        )
        for psm in (10, 13, 7):
            config = (
                f"--oem 3 --psm {psm} "
                f"-c tessedit_char_whitelist={whitelist}"
            )
            try:
                data = pytesseract.image_to_data(
                    padded, config=config,
                    output_type=pytesseract.Output.DICT,
                )
                for i, token in enumerate(data["text"]):
                    token = token.strip()
                    if not token:
                        continue
                    clean = "".join(c for c in token.upper() if c in wl_set)
                    if not clean:
                        continue
                    try:
                        conf = float(data["conf"][i]) / 100.0
                    except (ValueError, TypeError):
                        conf = 0.0
                    if conf > best_conf:
                        best_char, best_conf = clean[0], max(0.0, conf)
            except Exception as exc:
                logger.debug("Tesseract PSM %d variant failed: %s", psm, exc)

        if best_conf >= 0.70:
            break  # confident enough, skip remaining variants

    # EasyOCR fallback — feed the original colour crop for best accuracy
    if best_conf < 0.50 and _EASYOCR_AVAILABLE:
        try:
            reader = _get_easy_reader()
            rgb = cv2.cvtColor(bgr_scaled, cv2.COLOR_BGR2RGB)
            results = reader.readtext(rgb, allowlist=whitelist,
                                       detail=1, paragraph=False)
            for _, text, conf in results:
                clean = "".join(c for c in text.upper() if c in wl_set)
                if clean and float(conf) > best_conf:
                    best_char, best_conf = clean[0], float(conf)
        except Exception as exc:
            logger.debug("EasyOCR single-char failed: %s", exc)

    # ── Narrow-box heuristic (digit-only whitelist) ───────────────────────
    # On meter drum displays the digit '1' is the only character with an
    # aspect ratio (w/h) below ~0.40.  All other digits (0,2–9) are at
    # least 0.50 wide relative to their height.  When every OCR attempt
    # has failed AND the box is that narrow, it is almost certainly '1'.
    if best_char == "?" and whitelist == "0123456789":
        aspect = w_roi / h_roi   # original (pre-scale) dimensions
        if aspect < 0.40:
            logger.debug(
                "Narrow-box heuristic: returning '1' (aspect=%.2f, w=%d, h=%d)",
                aspect, w_roi, h_roi,
            )
            return "1", 0.45

    return best_char, best_conf


def _full_image_ocr_fallback(
    bgr: np.ndarray,
    num_chars: int,
    whitelist: str,
) -> str:
    """
    Fallback: run OCR on the full image as a single string,
    then filter to whitelist and pad/trim to num_chars.
    """
    wl_set = set(whitelist)

    if _EASYOCR_AVAILABLE:
        try:
            reader = _get_easy_reader()
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            results = reader.readtext(rgb, allowlist=whitelist,
                                       detail=1, paragraph=False)
            # Sort detections left-to-right
            items: list[tuple[float, str]] = []
            for bbox, text, conf in results:
                cx = float(np.mean([p[0] for p in bbox]))
                clean = "".join(c for c in text.upper() if c in wl_set)
                if clean:
                    items.append((cx, clean))
            items.sort(key=lambda x: x[0])
            combined = "".join(t for _, t in items)
            if len(combined) >= num_chars:
                return combined[:num_chars]
            return combined + "?" * (num_chars - len(combined))
        except Exception as exc:
            logger.debug("Full-image EasyOCR fallback failed: %s", exc)

    # Tesseract fallback
    config = f"--oem 3 --psm 7 -c tessedit_char_whitelist={whitelist}"
    try:
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY) if bgr.ndim == 3 else bgr
        text = pytesseract.image_to_string(gray, config=config).strip()
        clean = "".join(c for c in text.upper() if c in wl_set)
        if len(clean) >= num_chars:
            return clean[:num_chars]
        return clean + "?" * (num_chars - len(clean))
    except Exception as exc:
        logger.debug("Full-image Tesseract fallback failed: %s", exc)

    return "?" * num_chars


def _crop_to_digit_row(
    binary: np.ndarray,
    margin: int = 8,
) -> tuple[np.ndarray, int]:
    """
    Crop a binary image to the horizontal band that contains the digits,
    using vertical edge energy to locate the active rows.

    Returns (cropped_binary, y_offset) so callers can translate bboxes back.
    """
    h = binary.shape[0]
    # Horizontal edge energy per row
    sobely = cv2.Sobel(binary.astype(np.float32), cv2.CV_64F, 0, 1, ksize=3)
    row_e = np.mean(np.abs(sobely), axis=1)
    smooth = np.convolve(row_e, np.ones(7) / 7, mode="same")
    thresh = smooth.max() * 0.15
    active = np.where(smooth > thresh)[0]
    if len(active) == 0:
        return binary, 0
    y1 = max(0, int(active[0]) - margin)
    y2 = min(h, int(active[-1]) + margin)
    if y2 - y1 < h * 0.20:   # crop is suspiciously small — skip
        return binary, 0
    return binary[y1:y2, :], y1


def segment_and_read(
    bgr: np.ndarray,
    num_chars: int,
    preprocess_fn,
    whitelist: str,
    debug_dir: str | Path | None = None,
    debug_label: str = "segmentation",
) -> tuple[str, float, list[dict]]:
    """
    Character-by-character OCR pipeline.

    1. Upscale if small
    2. Preprocess → binary
    3. Crop to digit row (removes labels/borders that create false contours)
    4. Find contours with expected-width filtering → character bounding boxes
    5. If contours fail → equal-width column slicing
    6. Recognise each character individually (PSM 10/13/7 cascade + EasyOCR)
    7. Pad/trim to exactly num_chars
    8. If too many '?' → fallback to full-image OCR

    Returns (text, mean_confidence, bounding_boxes).
    """
    # --- Upscale if small ---
    h, w = bgr.shape[:2]
    scale = 1.0
    if w < 400:
        scale = 400.0 / w
        bgr = cv2.resize(bgr, (int(w * scale), int(h * scale)),
                         interpolation=cv2.INTER_CUBIC)

    binary_full = preprocess_fn(bgr)
    h_full, w_img = binary_full.shape[:2]

    # --- Crop to the digit row to remove noise above/below ---
    binary, y_offset = _crop_to_digit_row(binary_full)
    h_img = binary.shape[0]

    # --- Contour-based segmentation with width filtering ---
    boxes = _find_char_contours(binary, expected_num=num_chars)
    logger.debug("Contour segmentation found %d boxes (need %d)", len(boxes), num_chars)

    if len(boxes) < max(2, int(num_chars * 0.5)):
        # Fall back to equal-width slicing on the cropped digit row
        boxes = _equal_width_slices(w_img, h_img, num_chars)
        logger.debug("Too few contours; falling back to equal-width column slicing")
    elif len(boxes) > num_chars:
        # Too many boxes — merge the narrowest adjacent pair repeatedly until
        # we have the right count.  This fixes '1' being split into two thin
        # fragments by the contour detector.
        while len(boxes) > num_chars:
            min_w_idx = min(range(len(boxes) - 1),
                            key=lambda i: boxes[i][2] + boxes[i + 1][2])
            ax, ay, aw, ah = boxes[min_w_idx]
            bx, by, bw, bh = boxes[min_w_idx + 1]
            merged_box = (
                min(ax, bx),
                min(ay, by),
                max(ax + aw, bx + bw) - min(ax, bx),
                max(ay + ah, by + bh) - min(ay, by),
            )
            boxes = boxes[:min_w_idx] + [merged_box] + boxes[min_w_idx + 2:]
        logger.debug("Merged excess boxes down to %d", num_chars)

    # --- Recognise each character from the original colour image ---
    # Boxes are in (cropped) binary coordinates.  Map back to the upscaled BGR
    # image by adding y_offset (removed by _crop_to_digit_row).
    # This gives _recognize_char the full-colour pixel data instead of a
    # distorted binary slice, which is critical for the coloured fraction zone.
    chars: list[str] = []
    confs: list[float] = []
    bb_list: list[dict] = []
    h_bgr, w_bgr = bgr.shape[:2]
    for (bx, by, bw, bh) in boxes:
        # Coordinates in the upscaled BGR image
        bgr_y1 = min(y_offset + by, h_bgr)
        bgr_y2 = min(y_offset + by + bh, h_bgr)
        bgr_x1 = min(bx, w_bgr)
        bgr_x2 = min(bx + bw, w_bgr)
        bgr_roi = bgr[bgr_y1:bgr_y2, bgr_x1:bgr_x2]

        if bgr_roi.size == 0:
            chars.append("?")
            confs.append(0.0)
            continue
        ch, conf = _recognize_char(bgr_roi, whitelist)
        chars.append(ch)
        confs.append(conf)
        # Bounding box in original (pre-upscale) coordinates
        bb_list.append({
            "char": ch,
            "x": int(bx / scale),
            "y": int((by + y_offset) / scale),
            "width": int(bw / scale),
            "height": int(bh / scale),
            "confidence": round(conf * 100, 2),
        })

    result = "".join(chars)

    # --- Pad or trim to exactly num_chars ---
    if len(result) < num_chars:
        result = result + "?" * (num_chars - len(result))
    elif len(result) > num_chars:
        result = result[:num_chars]

    # --- Confidence gate: mark low-confidence per-char results as '?' --------
    # Tesseract PSM 10 on small, noisy crops can return wrong characters with
    # low-but-positive confidence (e.g. 3–27%).  The condition `conf > best_conf`
    # accepts these because they beat 0.0.  We demote anything below 0.45 to '?'
    # so that the gap-filling step (full-image EasyOCR, much more noise-robust)
    # can correct them.  Positions already recognised with high confidence are
    # not touched.
    RELIABLE_CONF = 0.45
    result_list = list(result)
    for i, c in enumerate(confs):
        if i < len(result_list) and c < RELIABLE_CONF and result_list[i] != "?":
            logger.debug(
                "Demoting char '%s' at pos %d (conf=%.2f < %.2f) to '?'",
                result_list[i], i, c, RELIABLE_CONF,
            )
            result_list[i] = "?"
    result = "".join(result_list)

    # --- Gap-filling: if ANY position is '?', try to fill from full-image OCR ---
    # Running EasyOCR on the whole digit row is far more reliable than on
    # isolated single characters — it has word context and a trained sequence
    # model.  We only use it to fill positions that per-char OCR couldn't read,
    # so we don't overwrite high-confidence correct results.
    if "?" in result and _EASYOCR_AVAILABLE:
        try:
            reader = _get_easy_reader()
            wl_set = set(whitelist)

            # Try the original image AND a CLAHE-enhanced version — the
            # enhanced variant helps on dark/noisy backgrounds (meter drums),
            # and the original helps on well-lit label images.
            gray_full = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY) if bgr.ndim == 3 else bgr
            clahe_full = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(gray_full)
            bgr_enh = cv2.cvtColor(clahe_full, cv2.COLOR_GRAY2BGR)

            best_full_text = "?" * num_chars
            for img_for_gap in (bgr, bgr_enh):
                rgb_full = cv2.cvtColor(img_for_gap, cv2.COLOR_BGR2RGB)
                full_dets = reader.readtext(rgb_full, allowlist=whitelist,
                                             detail=1, paragraph=False)
                # Build (centre_x, char) list sorted left-to-right
                full_chars: list[tuple[float, str]] = []
                for bbox, text, _conf in full_dets:
                    cx = float(np.mean([p[0] for p in bbox]))
                    clean = "".join(c for c in text.upper() if c in wl_set)
                    for ch in clean:
                        full_chars.append((cx, ch))
                full_chars.sort(key=lambda t: t[0])
                candidate = "".join(c for _, c in full_chars)
                candidate = (candidate + "?" * num_chars)[:num_chars]
                if candidate.count("?") < best_full_text.count("?"):
                    best_full_text = candidate

            logger.debug("Gap-filling full-image OCR produced: %r", best_full_text)

            # Fill only '?' positions — never overwrite confident per-char hits
            result_list = list(result)
            full_list = list(best_full_text)
            for i in range(num_chars):
                if result_list[i] == "?" and i < len(full_list) and full_list[i] != "?":
                    result_list[i] = full_list[i]
                    logger.debug("Gap-filled pos %d: '%s'", i, full_list[i])
            result = "".join(result_list)
        except Exception as exc:
            logger.debug("Gap-filling EasyOCR failed: %s", exc)

    # --- Full-image fallback when still too many unknowns ---
    unknown_count = result.count("?")
    if unknown_count > num_chars // 2:
        logger.debug("Too many unknowns (%d/%d); trying full-image OCR fallback",
                     unknown_count, num_chars)
        fallback = _full_image_ocr_fallback(bgr, num_chars, whitelist)
        if fallback.count("?") < unknown_count:
            result = fallback

    mean_conf = round(float(np.mean(confs)), 3) if confs else 0.0

    # --- Debug: save annotated binary + detected boxes ---
    if debug_dir is not None:
        debug_dir = Path(debug_dir)
        debug_dir.mkdir(parents=True, exist_ok=True)
        # Draw on the cropped binary so boxes are in the right coordinate space
        debug_img = cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR)
        for i, (bx, by, bw, bh) in enumerate(boxes):
            color = (0, 255, 0) if i < len(chars) and chars[i] != "?" else (0, 0, 255)
            cv2.rectangle(debug_img, (bx, by), (bx + bw, by + bh), color, 2)
            if i < len(chars):
                cv2.putText(debug_img, chars[i], (bx, max(by - 5, 12)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 0), 2)
        cv2.imwrite(str(debug_dir / f"debug_{debug_label}.png"), debug_img)
        # Also save the full binary (before row-crop) for comparison
        cv2.imwrite(str(debug_dir / f"debug_{debug_label}_full_binary.png"), binary_full)
        logger.debug("Debug images saved to %s", debug_dir)

    return result, mean_conf, bb_list


def _easyocr_zone(
    bgr_zone: np.ndarray,
    target_len: int,
    conf_min: float = 0.1,
) -> tuple[str, float, list]:
    """
    Run EasyOCR on a single BGR image zone.
    Tries 8 preprocessing variants: original, inverted, CLAHE-enhanced,
    sharpened, upscaled, and combinations — picks the best digit string.
    Returns (digit_string, mean_conf, raw_detections).
    """
    reader = _get_easy_reader()
    all_detections: list[tuple] = []

    def _clahe(img: np.ndarray) -> np.ndarray:
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        lab[:, :, 0] = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4)).apply(lab[:, :, 0])
        return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    def _sharpen(img: np.ndarray) -> np.ndarray:
        k = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        return cv2.filter2D(img, -1, k)

    def _upscale2x(img: np.ndarray) -> np.ndarray:
        h, w = img.shape[:2]
        return cv2.resize(img, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)

    # Pre-upscale once so all variants operate at the same coordinate space.
    # This avoids mixing original-scale and 2×-scale bounding boxes which
    # breaks left-to-right deduplication and ordering.
    h_z, w_z = bgr_zone.shape[:2]
    if w_z < 400:
        scale = 400 / w_z
        bgr_zone = cv2.resize(bgr_zone, (int(w_z * scale), int(h_z * scale)),
                              interpolation=cv2.INTER_CUBIC)

    enhanced  = _clahe(bgr_zone)
    sharpened = _sharpen(bgr_zone)
    variants  = [
        bgr_zone,
        cv2.bitwise_not(bgr_zone),
        enhanced,
        cv2.bitwise_not(enhanced),
        sharpened,
        cv2.bitwise_not(sharpened),
    ]

    for img in variants:
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        try:
            results = reader.readtext(rgb, allowlist="0123456789",
                                       detail=1, paragraph=False)
            all_detections.extend(results)
        except Exception as exc:
            logger.debug("EasyOCR call failed: %s", exc)

    text, conf = _best_digit_string_from_detections(
        all_detections, target_len, conf_min
    )
    return text, conf, all_detections




def _easyocr_digits_zones(
    bgr: np.ndarray,
    integer_digits: int,
    fraction_digits: int,
    positional_split: bool = False,
) -> tuple[str, float]:
    """
    Run EasyOCR separately on the integer zone and fraction zone, then concatenate.

    Parameters
    ----------
    positional_split : bool
        When True, always split at integer_digits/total_digits of image width.
        When False (default), use hue-based boundary detection with positional fallback.
    """
    total_digits = integer_digits + fraction_digits

    try:
        reader = _get_easy_reader()
    except Exception as exc:
        logger.warning("EasyOCR zones: reader unavailable: %s", exc)
        return "?" * total_digits, 0.0

    # ── Find the zone boundary ────────────────────────────────────────────────
    h, w = bgr.shape[:2]
    if positional_split:
        boundary = int(w * integer_digits / total_digits)
        logger.debug("Positional split: boundary x=%d (%d/%d of w=%d)",
                     boundary, integer_digits, total_digits, w)
    else:
        boundary = _find_dark_boundary(bgr)
        if boundary <= 0:
            boundary = int(w * integer_digits / total_digits)

    black_zone = bgr[:, :boundary]
    red_zone   = bgr[:, boundary:]

    clahe = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(4, 4))

    def _zone_variants(zone_bgr: np.ndarray) -> list[np.ndarray]:
        """Return BGR preprocessing variants for a single zone."""
        zh, zw = zone_bgr.shape[:2]
        if zw < 80:
            return [zone_bgr]
        # Upscale if tiny
        if zw < 300:
            scale = 300 / zw
            zone_bgr = cv2.resize(zone_bgr,
                                   (int(zw * scale), int(zh * scale)),
                                   interpolation=cv2.INTER_CUBIC)
        try:
            dn = cv2.fastNlMeansDenoisingColored(zone_bgr, None, 7, 7, 7, 21)
        except Exception:
            dn = zone_bgr

        gray     = cv2.cvtColor(dn, cv2.COLOR_BGR2GRAY)
        blue     = dn[:, :, 0]
        enh_gray = clahe.apply(gray)
        enh_blue = clahe.apply(blue)
        return [
            dn,
            cv2.cvtColor(enh_gray, cv2.COLOR_GRAY2BGR),
            cv2.cvtColor(enh_blue, cv2.COLOR_GRAY2BGR),
        ]

    def _read_zone(zone_bgr: np.ndarray, n_digits: int) -> tuple[str, float]:
        """Read exactly n_digits from a zone using EasyOCR."""
        best_text = "?" * n_digits
        best_conf = 0.0
        best_known = 0

        for variant in _zone_variants(zone_bgr):
            rgb = cv2.cvtColor(variant, cv2.COLOR_BGR2RGB)
            try:
                dets = reader.readtext(
                    rgb,
                    allowlist="0123456789",
                    detail=1,
                    paragraph=False,
                    width_ths=0.2,
                )
            except Exception as exc:
                logger.debug("EasyOCR zone variant failed: %s", exc)
                continue

            # Collect all digit characters sorted left-to-right
            chars: list[tuple[float, str, float]] = []  # (cx, char, conf)
            for bbox, text, conf in dets:
                clean = re.sub(r"[^0-9]", "", text)
                if not clean or conf < 0.1:
                    continue
                xs    = [p[0] for p in bbox]
                x_l   = float(min(xs))
                x_r   = float(max(xs))
                cw    = (x_r - x_l) / max(len(clean), 1)
                for i, ch in enumerate(clean):
                    chars.append((x_l + cw * (i + 0.5), ch, float(conf)))

            if not chars:
                continue

            chars.sort(key=lambda x: x[0])
            combined = "".join(c for _, c, _ in chars)
            mean_c   = float(np.mean([cf for _, _, cf in chars]))

            if len(combined) < n_digits:
                combined = combined + "?" * (n_digits - len(combined))
            else:
                combined = combined[:n_digits]

            known = sum(1 for c in combined if c != "?")
            if (known, mean_c) > (best_known, best_conf):
                best_text  = combined
                best_conf  = mean_c
                best_known = known

        return best_text, best_conf

    int_text,  int_conf  = _read_zone(black_zone, integer_digits)
    frac_text, frac_conf = _read_zone(red_zone,   fraction_digits)

    combined = int_text + frac_text
    mean_c   = float(np.mean([int_conf, frac_conf]))
    logger.debug("EasyOCR zones: int=%r frac=%r", int_text, frac_text)
    return combined, mean_c



def _easyocr_digits_ltr(
    bgr: np.ndarray,
    total_digits: int,
    conf_min: float = 0.1,
) -> tuple[str, float, list]:
    """
    Run EasyOCR on multiple preprocessing variants of the whole image,
    collect every digit detection, deduplicate by x-position, sort
    left-to-right, concatenate, pad/truncate to exactly total_digits.

    Returns (digit_string, mean_conf, raw_detections).
    """
    reader = _get_easy_reader()

    def _clahe_bgr(img: np.ndarray) -> np.ndarray:
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        lab[:, :, 0] = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4)).apply(lab[:, :, 0])
        return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    def _sharpen_bgr(img: np.ndarray) -> np.ndarray:
        k = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
        return cv2.filter2D(img, -1, k)

    # Pre-upscale so all variants share the same coordinate space
    h_i, w_i = bgr.shape[:2]
    if w_i < 800:
        scale = 800 / w_i
        bgr = cv2.resize(bgr, (int(w_i * scale), int(h_i * scale)),
                         interpolation=cv2.INTER_CUBIC)

    enhanced  = _clahe_bgr(bgr)
    sharpened = _sharpen_bgr(bgr)

    # Blue channel: white digits appear bright on BOTH dark navy and red backgrounds
    gray_blue = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)   # placeholder init
    blue_ch   = bgr[:, :, 0]
    blue_enh  = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(4, 4)).apply(blue_ch)
    blue_bgr  = cv2.cvtColor(blue_enh, cv2.COLOR_GRAY2BGR)

    variants = [
        bgr,
        enhanced,
        blue_bgr,                          # ← blue-channel variant (best for red zone)
        cv2.bitwise_not(enhanced),
        sharpened,
        cv2.bitwise_not(sharpened),
    ]

    all_detections: list[tuple] = []
    for img in variants:
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        try:
            results = reader.readtext(rgb, allowlist="0123456789",
                                       detail=1, paragraph=False)
            all_detections.extend(results)
        except Exception as exc:
            logger.debug("EasyOCR call failed: %s", exc)

    # Deduplicate detections by x-position (within 10px = same digit)
    items: list[tuple[float, str, float]] = []
    for bbox, text, conf in all_detections:
        if conf < conf_min:
            continue
        digits = _clean_digits(text)
        if not digits:
            continue
        cx = float(np.mean([p[0] for p in bbox]))
        # Check if a detection at roughly the same x already exists
        is_dup = False
        for i, (ex_cx, ex_d, ex_c) in enumerate(items):
            if abs(cx - ex_cx) < 10 and len(digits) == len(ex_d):
                # Keep the higher-confidence one
                if conf > ex_c:
                    items[i] = (cx, digits, conf)
                is_dup = True
                break
        if not is_dup:
            items.append((cx, digits, conf))

    items.sort(key=lambda x: x[0])

    combined = "".join(d for _, d, _ in items)
    mean_conf = float(np.mean([c for _, _, c in items])) if items else 0.0

    result = _pad_digits(_clean_digits(combined), total_digits)
    return result, round(mean_conf, 3), all_detections


# ---------------------------------------------------------------------------
# Main class
# ---------------------------------------------------------------------------

class OCRExtractor:
    """
    Reusable OCR extractor.

    Parameters
    ----------
    confidence_threshold : float
        Bounding-box tokens with conf > 0 AND conf < threshold are dropped.
        conf == 0 tokens are kept (Tesseract returns 0 for single-block reads
        where per-token confidence is not computable).
    blur_threshold : float
        Laplacian-variance cutoff for blur detection.  0 = disabled.
    upscale_min_dim : int
        Upscale 2× when shortest dimension < this value.  Default 100.
    """

    def __init__(
        self,
        confidence_threshold: float = 60.0,
        blur_threshold: float = 40.0,
        upscale_min_dim: int = 300,
    ) -> None:
        self.confidence_threshold = confidence_threshold
        self.blur_threshold       = blur_threshold
        self.upscale_min_dim      = upscale_min_dim
        self._verify_tesseract()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def preprocess(self, image_path: str | Path | np.ndarray) -> np.ndarray:
        """
        Prepare image for OCR; returns a cleaned greyscale ndarray.
        Denoising and binarisation are skipped for photo-like images.
        """
        bgr  = _load_image(image_path)
        gray = self._to_gray(bgr)
        gray = self._upscale_if_small(gray)
        gray = self._enhance_contrast(gray)   # CLAHE first — reveals edges

        if _is_document_like(gray):
            gray = self._denoise(gray)        # denoise only for scans
            gray = _deskew(gray)
            gray = self._threshold(gray)      # Otsu binary
            gray = self._morphological_clean(gray)
            logger.debug("Document pipeline applied")
        else:
            gray = _deskew(gray)              # skip denoising for photos
            logger.debug("Photo pipeline applied (no denoise/threshold)")

        return gray

    def extract(self, image_path: str | Path | np.ndarray) -> dict[str, Any]:
        """
        Run OCR and return structured JSON-compatible dict::

            {
              "extracted_text": "Hello 123",
              "confidence":     87.4,
              "low_quality":    false,
              "bounding_boxes": [
                {"char": "Hello", "x": 10, "y": 5, "width": 60, "height": 20,
                 "confidence": 91.0}
              ]
            }
        """
        bgr  = _load_image(image_path)
        gray = self._to_gray(bgr)

        blur        = _blur_score(gray)
        low_quality = self.blur_threshold > 0 and blur < self.blur_threshold
        if low_quality:
            logger.warning("Blurry image (Laplacian=%.1f).", blur)

        preprocessed = self.preprocess(bgr)

        # Try multiple configs; keep the result with the most alphanumeric chars
        raw_text, mean_conf = _best_ocr(
            preprocessed,
            [_CFG_BLOCK, _CFG_LINE],
        )

        boxes = _ocr_bounding_boxes(
            preprocessed,
            config=_CFG_BLOCK,
            threshold=self.confidence_threshold,
        )

        return {
            "extracted_text": raw_text,
            "confidence":     mean_conf,
            "low_quality":    low_quality,
            "bounding_boxes": boxes,
        }

    def extract_meter_reading(
        self,
        image_path: str | Path | np.ndarray,
        integer_digits: int = 5,
        fraction_digits: int = 3,
        positional_split: bool = False,
        debug_dir: str | Path | None = None,
    ) -> dict[str, Any]:
        """
        Extract a meter reading.

        Parameters
        ----------
        positional_split : bool
            When True, always split the image at exactly
            ``integer_digits / (integer_digits + fraction_digits)`` of the
            image width — no hue/colour boundary detection.  Use this when
            the image is a tight crop of the digit display and the first
            ``integer_digits`` drums are always on the left.

        Returns
        -------
        {
          "integer_part"  : "01001",
          "fraction_part" : "397",
          "reading"       : "01001.397",
          "raw_text"      : "01001397",
          "confidence"    : 0.0,
          "low_quality"   : false,
          "bounding_boxes": [...],
          "engine_results": [...]
        }
        """
        bgr = _load_image(image_path)
        gray_orig = self._to_gray(bgr)

        blur        = _blur_score(gray_orig)
        low_quality = self.blur_threshold > 0 and blur < self.blur_threshold

        total_digits = integer_digits + fraction_digits
        _DIGIT_WL    = "0123456789"

        raw_text  = "?" * total_digits
        mean_conf = 0.0
        all_boxes: list[dict] = []

        # Per-engine results — always populated regardless of which wins
        engine_results: list[dict] = []

        # ── ENGINE 1: MeterOCREngine (projection-profile + EasyOCR + Tesseract)
        eng1_text = "?" * total_digits
        eng1_conf = 0.0
        if _NEW_ENGINE_AVAILABLE:
            try:
                engine = _MeterOCREngine(
                    whitelist=_DIGIT_WL,
                    target_width=800,
                    denoise=True,
                    min_slot_conf=0.45,
                )
                eng_result = engine.read_meter(
                    bgr,
                    num_chars=total_digits,
                    debug_dir=debug_dir,
                    debug_label="meter",
                )
                eng1_text = eng_result.get("text", "?" * total_digits)
                eng1_conf = float(eng_result.get("confidence", 0.0))
                all_boxes = [
                    {
                        "char":       s["char"],
                        "x":          s["x"],
                        "y":          0,
                        "width":      s["width"],
                        "height":     bgr.shape[0],
                        "confidence": round(s["confidence"] * 100, 2),
                    }
                    for s in eng_result.get("slots", [])
                ]
                logger.debug("Engine1 (MeterOCREngine): %r conf=%.2f", eng1_text, eng1_conf)
            except Exception as exc:
                logger.warning("Engine1 (MeterOCREngine) failed: %s", exc)

        engine_results.append({
            "name":       "Projection+EasyOCR+Tesseract",
            "raw_text":   eng1_text,
            "confidence": round(eng1_conf, 3),
        })

        # ── ENGINE 2: EasyOCR zone-split (black zone + red zone separately) ────
        eng2_text = "?" * total_digits
        eng2_conf = 0.0
        try:
            eng2_text, eng2_conf = _easyocr_digits_zones(
                bgr, integer_digits, fraction_digits,
                positional_split=positional_split,
            )
            logger.debug("Engine2 (EasyOCR zones): %r conf=%.2f", eng2_text, eng2_conf)
        except Exception as exc:
            logger.debug("Engine2 (EasyOCR zones) failed: %s", exc)

        engine_results.append({
            "name":       "EasyOCR Zone-Split",
            "raw_text":   eng2_text,
            "confidence": round(eng2_conf, 3),
        })

        # ── Choose winner: fewest unknowns, then highest confidence ───────────
        def _score(r: dict) -> tuple[int, float]:
            unknowns = r["raw_text"].count("?")
            return (-unknowns, r["confidence"])

        winner = max(engine_results, key=_score)
        raw_text  = winner["raw_text"]
        mean_conf = winner["confidence"]

        # Mark which engines agree with the winner
        winner_digits = re.sub(r"[^0-9]", "", raw_text)
        for er in engine_results:
            er_digits = re.sub(r"[^0-9]", "", er["raw_text"])
            er["winner"]  = er["raw_text"] == raw_text
            er["agrees"]  = bool(er_digits and er_digits == winner_digits)
            er["reading"] = (
                f"{er['raw_text'][:integer_digits]}.{er['raw_text'][integer_digits:total_digits]}"
                if len(er["raw_text"]) >= total_digits else er["raw_text"]
            )

        # ── Split into integer + fraction parts ───────────────────────────────
        int_digits_str  = raw_text[:integer_digits]
        frac_digits_str = raw_text[integer_digits:total_digits]

        int_digits_str  = (int_digits_str  + "?" * integer_digits)[:integer_digits]
        frac_digits_str = (frac_digits_str + "?" * fraction_digits)[:fraction_digits]
        mean_conf       = round(float(mean_conf), 2)

        reading = f"{int_digits_str}.{frac_digits_str}"

        return {
            "integer_part":   int_digits_str,
            "fraction_part":  frac_digits_str,
            "reading":        reading,
            "raw_text":       int_digits_str + frac_digits_str,
            "confidence":     mean_conf,
            "low_quality":    low_quality,
            "bounding_boxes": all_boxes,
            "engine_results": engine_results,   # ← new: per-engine breakdown
        }

    def visualize(
        self,
        image_path: str | Path | np.ndarray,
        output_path: str | Path | None = None,
        show: bool = False,
        meter_mode: bool = False,
    ) -> np.ndarray:
        """
        Draw bounding boxes on the original colour image.
        When ``meter_mode=True`` uses ``extract_meter_reading()`` and also draws
        the dark/light boundary line and the formatted reading as an overlay.
        """
        bgr = _load_image(image_path)

        if meter_mode:
            result = self.extract_meter_reading(image_path)
            # draw boundary
            boundary = _find_dark_boundary(bgr)
            h        = bgr.shape[0]
            annotated = bgr.copy()
            cv2.line(annotated, (boundary, 0), (boundary, h), (0, 255, 255), 2)
            # overlay reading
            cv2.putText(
                annotated,
                f"  {result['reading']}",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                1.0, (0, 255, 0), 2, cv2.LINE_AA,
            )
        else:
            result    = self.extract(image_path)
            annotated = bgr.copy()

        for bb in result["bounding_boxes"]:
            x, y, bw, bh = bb["x"], bb["y"], bb["width"], bb["height"]
            cv2.rectangle(annotated, (x, y), (x + bw, y + bh), (0, 200, 0), 2)
            conf_str = "?" if bb["confidence"] == 0 else f"{bb['confidence']:.0f}%"
            cv2.putText(annotated, f"{bb['char']} {conf_str}",
                        (x, max(y - 4, 12)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                        (0, 140, 255), 1, cv2.LINE_AA)

        if output_path:
            cv2.imwrite(str(output_path), annotated)
        if show:
            cv2.imshow("OCR", annotated)
            cv2.waitKey(0)
            cv2.destroyAllWindows()

        return annotated

    # ------------------------------------------------------------------
    # Internal preprocessing steps
    # ------------------------------------------------------------------

    @staticmethod
    def _to_gray(bgr: np.ndarray) -> np.ndarray:
        return bgr if bgr.ndim == 2 else cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    def _upscale_if_small(self, gray: np.ndarray) -> np.ndarray:
        h, w = gray.shape[:2]
        if min(h, w) < self.upscale_min_dim:
            gray = cv2.resize(gray, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
            logger.debug("Upscaled %dx%d → %dx%d", w, h, w*2, h*2)
        return gray

    @staticmethod
    def _denoise(gray: np.ndarray) -> np.ndarray:
        return cv2.fastNlMeansDenoising(gray, h=5,
                                         templateWindowSize=7,
                                         searchWindowSize=21)

    @staticmethod
    def _enhance_contrast(gray: np.ndarray) -> np.ndarray:
        return cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8)).apply(gray)

    @staticmethod
    def _threshold(gray: np.ndarray) -> np.ndarray:
        _, binary = cv2.threshold(gray, 0, 255,
                                   cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return binary

    @staticmethod
    def _morphological_clean(binary: np.ndarray) -> np.ndarray:
        k = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        return cv2.morphologyEx(binary, cv2.MORPH_OPEN, k, iterations=1)

    @staticmethod
    def _verify_tesseract() -> None:
        try:
            pytesseract.get_tesseract_version()
        except pytesseract.TesseractNotFoundError:
            raise EnvironmentError(
                "Tesseract not found.\n"
                "  Windows : https://github.com/UB-Mannheim/tesseract/wiki\n"
                "  macOS   : brew install tesseract\n"
                "  Linux   : sudo apt install tesseract-ocr"
            )
