"""
MeterOCREngine — ground-up, stable OCR for utility meter digit displays.

Architecture
------------
1. Upscale   : bring image width to ≥ 800 px (INTER_CUBIC).
2. Denoise   : fastNlMeansDenoisingColored removes mesh/grain noise.
3. Row-crop  : horizontal projection profile isolates the digit row.
4. Binarise  : multi-strategy, picks the thresholded image whose
               foreground density is closest to a target range.
5. Segment   : COLUMN projection profile → gap detection finds
               individual character columns (no fragile contours).
6. Coarse ID : EasyOCR over the full digit-row image; map each
               detected character to the nearest column slot by
               x-centre proximity.
7. Fine ID   : for each slot still empty (or low-confidence after
               coarse step), run Tesseract PSM-10 on the cropped
               character cell.
8. '1' fix   : slots whose column width is < 40 % of the median
               column width are forcibly set to '1'.
9. Output    : always return exactly `num_chars` characters.

Usage
-----
    from meter_ocr_engine import MeterOCREngine

    engine = MeterOCREngine()
    result = engine.read_meter(bgr_image, num_chars=8)
    # result = {"text": "01234567", "confidence": 0.92, "slots": [...]}
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any

import cv2
import numpy as np

try:
    import pytesseract
    _TESSERACT_OK = True
except ImportError:
    _TESSERACT_OK = False

try:
    import easyocr as _easyocr_mod
    _EASYOCR_AVAILABLE = True
except ImportError:
    _EASYOCR_AVAILABLE = False

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Module-level singleton for the EasyOCR reader (expensive to build)
# ---------------------------------------------------------------------------
_easy_reader: Any = None


def _get_reader() -> Any:
    global _easy_reader
    if _easy_reader is None:
        if not _EASYOCR_AVAILABLE:
            raise RuntimeError("EasyOCR not installed: pip install easyocr")
        logger.debug("Initialising EasyOCR reader …")
        _easy_reader = _easyocr_mod.Reader(["en"], gpu=False, verbose=False)
    return _easy_reader


# ---------------------------------------------------------------------------
# Step 1 – Upscale
# ---------------------------------------------------------------------------

def _upscale(bgr: np.ndarray, target_width: int = 800) -> np.ndarray:
    """Upscale image so width ≥ target_width using cubic interpolation."""
    h, w = bgr.shape[:2]
    if w >= target_width:
        return bgr
    scale = target_width / w
    new_w, new_h = int(w * scale), int(h * scale)
    return cv2.resize(bgr, (new_w, new_h), interpolation=cv2.INTER_CUBIC)


# ---------------------------------------------------------------------------
# Step 2 – Denoise
# ---------------------------------------------------------------------------

def _denoise(bgr: np.ndarray) -> np.ndarray:
    """
    Remove mesh/grain noise with fastNlMeansDenoisingColored.
    Conservative parameters preserve stroke edges.
    """
    try:
        return cv2.fastNlMeansDenoisingColored(bgr, None, h=7, hColor=7,
                                               templateWindowSize=7,
                                               searchWindowSize=21)
    except Exception as exc:
        logger.debug("Denoise failed (%s); using original.", exc)
        return bgr


# ---------------------------------------------------------------------------
# Step 3 – Row-crop: find the horizontal band that contains digits
# ---------------------------------------------------------------------------

def _crop_digit_row(bgr: np.ndarray, margin: int = 6) -> tuple[np.ndarray, int]:
    """
    Use a horizontal projection profile on a binarised image to find
    the row band with the most foreground pixels.

    Returns (cropped_bgr, y_offset) where y_offset is the top of the
    crop in the original image coordinates.
    """
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    # Adaptive threshold to get foreground
    binary = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY_INV,
        blockSize=15, C=5,
    )
    # Horizontal projection: sum of foreground pixels per row
    row_sum = binary.sum(axis=1).astype(float)

    # Smooth with a wide window to find the densest band
    k = max(3, len(row_sum) // 10)
    smoothed = np.convolve(row_sum, np.ones(k) / k, mode="same")

    threshold = smoothed.max() * 0.25
    active = np.where(smoothed > threshold)[0]
    if len(active) < 3:
        return bgr, 0  # can't find a band; return full image

    y1 = max(0, int(active[0]) - margin)
    y2 = min(bgr.shape[0], int(active[-1]) + margin + 1)

    # Only crop if the result is at least 20 % of the image height
    if (y2 - y1) < bgr.shape[0] * 0.20:
        return bgr, 0

    return bgr[y1:y2, :], y1


# ---------------------------------------------------------------------------
# Step 4 – Binarise: pick the best binary image from several strategies
# ---------------------------------------------------------------------------

def _binarise_meter(bgr: np.ndarray) -> np.ndarray:
    """
    Binarise a meter digit row that has two distinct background zones:
      • Left  zone: dark/navy background, white digits
      • Right zone: red/coloured background, white digits

    Strategy: build candidates from multiple strategies, score by how close
    the foreground density is to 35%, pick the best. Then run the same
    scoring independently on the left and right halves and stitch — this
    way each zone gets the preprocessing that suits it best.
    """
    h, w = bgr.shape[:2]
    clahe4 = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(4, 4))
    clahe3 = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))

    def _candidates(img_bgr: np.ndarray) -> list[np.ndarray]:
        gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
        blue = img_bgr[:, :, 0]   # white digits appear bright on both dark and red bg

        # Denoise before binarising to reduce mesh/grain interference
        try:
            dn = cv2.fastNlMeansDenoising(gray, None, 9, 7, 21)
        except Exception:
            dn = gray

        enh3  = clahe3.apply(gray)
        enh4  = clahe4.apply(dn)
        enh_b = clahe4.apply(blue)

        cands = []

        # Blue channel (best for white-on-red zone)
        _, c = cv2.threshold(enh_b, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        cands.append(c)
        cands.append(cv2.bitwise_not(c))

        # CLAHE grayscale Otsu
        _, c = cv2.threshold(enh4, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        cands.append(c)
        cands.append(cv2.bitwise_not(c))

        # Adaptive threshold on denoised enhanced
        c = cv2.adaptiveThreshold(enh4, 255,
                                   cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                   cv2.THRESH_BINARY_INV, 25, -5)
        cands.append(c)
        cands.append(cv2.bitwise_not(c))

        # Plain Otsu on original gray
        _, c = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        cands.append(c)

        return cands

    def _best_candidate(cands: list[np.ndarray]) -> np.ndarray:
        TARGET = 0.35
        px     = cands[0].size
        best   = cands[0]
        bdist  = float("inf")
        for c in cands:
            dist = abs(c.sum() / 255.0 / px - TARGET)
            if dist < bdist:
                bdist = dist
                best  = c
        return best

    # Process whole image
    best_full = _best_candidate(_candidates(bgr))

    # Process left half (dark zone) and right half (coloured zone) separately
    mid = w // 2
    if mid > 10:
        left_best  = _best_candidate(_candidates(bgr[:, :mid]))
        right_best = _best_candidate(_candidates(bgr[:, mid:]))
        zoned = np.concatenate([left_best, right_best], axis=1)
    else:
        zoned = best_full

    # Pick whichever is closer to 35% overall
    TARGET = 0.35
    px = h * w
    dist_full  = abs(best_full.sum() / 255.0 / px - TARGET)
    dist_zoned = abs(zoned.sum()     / 255.0 / px - TARGET)
    best_bin   = zoned if dist_zoned < dist_full else best_full

    # Morphological cleanup
    kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 3))
    kernel_open  = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    best_bin = cv2.morphologyEx(best_bin, cv2.MORPH_CLOSE, kernel_close)
    best_bin = cv2.morphologyEx(best_bin, cv2.MORPH_OPEN,  kernel_open)

    return best_bin


# ---------------------------------------------------------------------------
# Step 5 – Column-projection segmentation
# ---------------------------------------------------------------------------

def _projection_segment(binary: np.ndarray, num_chars: int) -> list[tuple[int, int]]:
    """
    Find character column boundaries using a vertical projection profile
    (sum of foreground pixels per column).

    Returns a list of (x_start, x_end) tuples, one per character slot,
    sorted left to right.  Always returns exactly `num_chars` slots.
    """
    h, w = binary.shape[:2] if binary.ndim == 3 else (binary.shape[0], binary.shape[1])
    col_sum = (binary > 0).sum(axis=0).astype(float)

    # Smooth to merge tiny gaps inside strokes
    k = max(3, w // 80)
    smoothed = np.convolve(col_sum, np.ones(k) / k, mode="same")

    # Threshold: a column is "active" if it has >5% of the max density
    threshold = max(1.0, smoothed.max() * 0.05)

    # Find runs of active columns
    active = (smoothed > threshold).astype(int)
    transitions = np.diff(np.concatenate([[0], active, [0]]))
    starts = np.where(transitions ==  1)[0]
    ends   = np.where(transitions == -1)[0]
    runs   = list(zip(starts.tolist(), ends.tolist()))  # (x_start, x_end_exclusive)

    # --- Adjust run count to num_chars ---
    if len(runs) == 0:
        # Fallback: equal-width slicing
        step = w / num_chars
        runs = [(int(i * step), int((i + 1) * step)) for i in range(num_chars)]

    elif len(runs) < num_chars:
        # Too few segments: split the widest ones
        while len(runs) < num_chars:
            widths  = [e - s for s, e in runs]
            idx     = int(np.argmax(widths))
            s, e    = runs[idx]
            mid     = (s + e) // 2
            runs[idx:idx + 1] = [(s, mid), (mid, e)]

    elif len(runs) > num_chars:
        # Too many: merge the narrowest adjacent pair
        while len(runs) > num_chars:
            widths = [e - s for s, e in runs]
            # Find narrowest run
            idx = int(np.argmin(widths))
            if idx == 0:
                # Merge with the right neighbour
                runs[0:2] = [(runs[0][0], runs[1][1])]
            elif idx == len(runs) - 1:
                # Merge with the left neighbour
                runs[-2:] = [(runs[-2][0], runs[-1][1])]
            else:
                # Merge with the smaller adjacent neighbour
                left_w  = runs[idx - 1][1] - runs[idx - 1][0]
                right_w = runs[idx + 1][1] - runs[idx + 1][0]
                if left_w <= right_w:
                    runs[idx - 1:idx + 1] = [(runs[idx - 1][0], runs[idx][1])]
                else:
                    runs[idx:idx + 2] = [(runs[idx][0], runs[idx + 1][1])]

    return runs  # list of (x_start, x_end), len == num_chars


# ---------------------------------------------------------------------------
# Step 6 – Coarse ID: EasyOCR on the full digit row, map to slots
# ---------------------------------------------------------------------------

def _easyocr_on_row(
    bgr_row: np.ndarray,
    whitelist: str,
    slots: list[tuple[int, int]],
) -> list[tuple[str, float]]:
    """
    Run EasyOCR on the full digit-row image and assign each detected
    character to the nearest slot by x-centre proximity.

    Returns a list of (char, confidence) of length len(slots).
    Empty/unmapped slots get ("?", 0.0).
    """
    n = len(slots)
    result = [("?", 0.0)] * n
    slot_centers = [(s + e) // 2 for s, e in slots]

    if not _EASYOCR_AVAILABLE:
        return result

    try:
        reader = _get_reader()
    except Exception as exc:
        logger.debug("EasyOCR reader unavailable: %s", exc)
        return result

    # Run EasyOCR on multiple preprocessings of the row image
    def _run_easy(img_bgr: np.ndarray) -> list[tuple[int, str, float]]:
        """Returns list of (x_centre, char, conf)."""
        detections: list[tuple[int, str, float]] = []
        rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        try:
            raw = reader.readtext(
                rgb,
                allowlist=whitelist,
                detail=1,
                paragraph=False,
                width_ths=0.3,      # allow very narrow characters
                ycenter_ths=0.9,
            )
        except Exception as exc:
            logger.debug("EasyOCR readtext failed: %s", exc)
            return detections

        for bbox, text, conf in raw:
            clean = re.sub(r"[^" + re.escape(whitelist) + r"]", "", text.upper())
            if not clean:
                continue
            xs = [p[0] for p in bbox]
            x_left  = float(min(xs))
            x_right = float(max(xs))
            char_w  = (x_right - x_left) / max(len(clean), 1)
            for i, ch in enumerate(clean):
                cx = int(x_left + char_w * (i + 0.5))
                detections.append((cx, ch, float(conf)))
        return detections

    # Collect detections from original + CLAHE + blue-channel variants
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
    gray  = cv2.cvtColor(bgr_row, cv2.COLOR_BGR2GRAY)
    enhanced = clahe.apply(gray)
    blue     = bgr_row[:, :, 0]

    all_detections: list[tuple[int, str, float]] = []
    all_detections.extend(_run_easy(bgr_row))
    all_detections.extend(_run_easy(cv2.cvtColor(enhanced, cv2.COLOR_GRAY2BGR)))
    all_detections.extend(_run_easy(cv2.cvtColor(blue, cv2.COLOR_GRAY2BGR)))

    if not all_detections:
        return result

    # Map each detection to the closest slot
    slot_votes: list[list[tuple[str, float]]] = [[] for _ in range(n)]
    slot_width_median = max(
        1, int(np.median([e - s for s, e in slots]))
    )

    for cx, ch, conf in all_detections:
        # Find the closest slot centre
        dists = [abs(cx - sc) for sc in slot_centers]
        best_slot = int(np.argmin(dists))
        # Accept only if within 1.5 slot widths
        if dists[best_slot] < slot_width_median * 1.5:
            slot_votes[best_slot].append((ch, conf))

    # For each slot, pick the highest-confidence detection
    for i, votes in enumerate(slot_votes):
        if votes:
            best = max(votes, key=lambda x: x[1])
            result[i] = best

    return result


# ---------------------------------------------------------------------------
# Step 7 – Fine ID: Tesseract PSM-10 on individual character cells
# ---------------------------------------------------------------------------

def _tesseract_char(
    bgr_cell: np.ndarray,
    whitelist: str,
) -> tuple[str, float]:
    """
    Run Tesseract in single-character mode (PSM 10) on a padded cell.
    Returns (char, confidence) or ("?", 0.0) if nothing recognised.
    """
    if not _TESSERACT_OK:
        return "?", 0.0

    TARGET_H = 64
    PAD      = 20

    h, w = bgr_cell.shape[:2]
    if h < 4 or w < 4:
        return "?", 0.0

    # Scale to target height
    scale   = TARGET_H / h
    new_w   = max(4, int(w * scale))
    resized = cv2.resize(bgr_cell, (new_w, TARGET_H), interpolation=cv2.INTER_CUBIC)

    # Pad sides (never stretch narrow chars like '1')
    if new_w < 40:
        left_pad  = (40 - new_w) // 2
        right_pad = 40 - new_w - left_pad
        resized   = cv2.copyMakeBorder(
            resized, PAD, PAD, left_pad + PAD, right_pad + PAD,
            cv2.BORDER_CONSTANT, value=(255, 255, 255),
        )
    else:
        resized = cv2.copyMakeBorder(
            resized, PAD, PAD, PAD, PAD,
            cv2.BORDER_CONSTANT, value=(255, 255, 255),
        )

    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
    enhanced = clahe.apply(gray)

    cfg_10 = (
        f"--oem 3 --psm 10 "
        f"-c tessedit_char_whitelist={whitelist}"
    )
    cfg_13 = (
        f"--oem 3 --psm 13 "
        f"-c tessedit_char_whitelist={whitelist}"
    )

    best_char = "?"
    best_conf = 0.0

    for img_variant in [enhanced, gray,
                        cv2.bitwise_not(enhanced),
                        resized[:, :, 0]]:  # blue channel
        for cfg in [cfg_10, cfg_13]:
            try:
                data = pytesseract.image_to_data(
                    img_variant, config=cfg,
                    output_type=pytesseract.Output.DICT,
                )
                for token, raw_conf in zip(data["text"], data["conf"]):
                    token = token.strip()
                    if not token:
                        continue
                    try:
                        conf_val = float(raw_conf) / 100.0
                    except (ValueError, TypeError):
                        conf_val = 0.0
                    # Keep only characters that are in the whitelist
                    valid = "".join(c for c in token.upper() if c in whitelist)
                    if valid and conf_val > best_conf:
                        best_char = valid[0]
                        best_conf = conf_val
                        if best_conf >= 0.70:
                            return best_char, best_conf
            except Exception as exc:
                logger.debug("Tesseract variant failed: %s", exc)

    return best_char, best_conf


# ---------------------------------------------------------------------------
# Step 8 – '1' heuristic: narrow slots are almost always '1'
# ---------------------------------------------------------------------------

def _apply_one_heuristic(
    chars: list[tuple[str, float]],
    slots: list[tuple[int, int]],
    whitelist: str,
) -> list[tuple[str, float]]:
    """
    If the whitelist contains only digits and a slot's width is
    < 45 % of the median slot width, override the character to '1'
    (with synthetic confidence 0.50 if current confidence is low).
    """
    if "0123456789" not in whitelist and not all(c in "0123456789" for c in whitelist):
        return chars  # not digit-only — skip

    widths = [e - s for s, e in slots]
    if not widths:
        return chars
    median_w = float(np.median(widths))
    result   = list(chars)

    for i, (s, e) in enumerate(slots):
        w = e - s
        if w < median_w * 0.45:
            ch, conf = result[i]
            if ch != "1":
                logger.debug("Slot %d: width %d < %.1f*0.45=%.1f → forcing '1'",
                             i, w, median_w, median_w * 0.45)
            result[i] = ("1", max(conf, 0.50))

    return result


# ---------------------------------------------------------------------------
# Main engine class
# ---------------------------------------------------------------------------

class MeterOCREngine:
    """
    Robust OCR engine for utility-meter digit displays.

    Parameters
    ----------
    whitelist : str
        Characters to accept.  Default is digits only.
    target_width : int
        Upscale images to at least this width before processing.
    denoise : bool
        Whether to run fastNlMeansDenoisingColored (adds ~0.3 s per call).
    min_slot_conf : float
        Slots with confidence below this threshold are sent to Tesseract
        for a second opinion.
    """

    def __init__(
        self,
        whitelist: str = "0123456789",
        target_width: int = 800,
        denoise: bool = True,
        min_slot_conf: float = 0.45,
    ) -> None:
        self.whitelist     = whitelist
        self.target_width  = target_width
        self.denoise       = denoise
        self.min_slot_conf = min_slot_conf

    # ------------------------------------------------------------------
    def read_meter(
        self,
        bgr: np.ndarray,
        num_chars: int = 8,
        debug_dir: str | Path | None = None,
        debug_label: str = "meter",
    ) -> dict[str, Any]:
        """
        Extract exactly `num_chars` characters from the digit display.

        Parameters
        ----------
        bgr : np.ndarray
            BGR image of the digit-display crop.
        num_chars : int
            Number of characters to return (e.g. 8 for meter, 11 for serial).
        debug_dir : str | Path | None
            If set, save annotated debug images here.
        debug_label : str
            Prefix for debug filenames.

        Returns
        -------
        dict with keys:
            text        : str   — exactly `num_chars` characters ('?' = unknown)
            confidence  : float — mean confidence across all slots
            slots       : list[dict]  — per-slot info (x, width, char, conf)
        """
        # ── 1. Upscale ────────────────────────────────────────────────
        bgr = _upscale(bgr, self.target_width)

        # ── 2. Denoise ────────────────────────────────────────────────
        if self.denoise:
            bgr = _denoise(bgr)

        # ── 3. Row-crop ───────────────────────────────────────────────
        bgr_row, y_off = _crop_digit_row(bgr)

        # ── 4. Binarise ───────────────────────────────────────────────
        binary = _binarise_meter(bgr_row)

        # ── 5. Column-projection segmentation ─────────────────────────
        slots = _projection_segment(binary, num_chars)

        # ── 6. Coarse ID: EasyOCR → slot assignment ───────────────────
        chars = _easyocr_on_row(bgr_row, self.whitelist, slots)

        # ── 7. Fine ID: Tesseract for uncertain slots ─────────────────
        for i, (ch, conf) in enumerate(chars):
            if ch == "?" or conf < self.min_slot_conf:
                s, e = slots[i]
                cell_bgr = bgr_row[:, s:e]
                t_char, t_conf = _tesseract_char(cell_bgr, self.whitelist)
                if t_char != "?" and t_conf > conf:
                    chars[i] = (t_char, t_conf)

        # ── 8. '1' heuristic ─────────────────────────────────────────
        chars = _apply_one_heuristic(chars, slots, self.whitelist)

        # ── Debug save ───────────────────────────────────────────────
        if debug_dir is not None:
            self._save_debug(bgr_row, binary, slots, chars,
                             debug_dir, debug_label)

        # ── Build output ─────────────────────────────────────────────
        text        = "".join(ch for ch, _ in chars)
        mean_conf   = float(np.mean([c for _, c in chars]))
        slot_info   = []
        for i, ((ch, conf), (s, e)) in enumerate(zip(chars, slots)):
            slot_info.append({
                "index":      i,
                "char":       ch,
                "confidence": round(conf, 3),
                "x":          int(s),
                "width":      int(e - s),
            })

        return {"text": text, "confidence": round(mean_conf, 3), "slots": slot_info}

    # ------------------------------------------------------------------
    def _save_debug(
        self,
        bgr_row: np.ndarray,
        binary: np.ndarray,
        slots: list[tuple[int, int]],
        chars: list[tuple[str, float]],
        debug_dir: str | Path,
        label: str,
    ) -> None:
        """Draw annotated debug images and save to debug_dir."""
        debug_dir = Path(debug_dir)
        debug_dir.mkdir(parents=True, exist_ok=True)

        # Annotate the BGR row image
        annotated = bgr_row.copy()
        h = annotated.shape[0]
        for i, ((ch, conf), (s, e)) in enumerate(zip(chars, slots)):
            color = (0, 255, 0) if ch != "?" else (0, 0, 255)
            cv2.rectangle(annotated, (s, 0), (e, h - 1), color, 2)
            cv2.putText(
                annotated, f"{ch}:{conf:.2f}",
                (s + 2, max(16, h // 3)),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1, cv2.LINE_AA,
            )
        cv2.imwrite(str(debug_dir / f"{label}_annotated.png"), annotated)

        # Save binary image
        cv2.imwrite(str(debug_dir / f"{label}_binary.png"), binary)
