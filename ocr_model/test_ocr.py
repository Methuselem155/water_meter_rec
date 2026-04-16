"""
Quick smoke-tests for OCRExtractor.

Run:
    python test_ocr.py
"""

import json
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Create a synthetic test image with known text
# ---------------------------------------------------------------------------

def make_test_image(text: str = "Hello123", path: str | None = None) -> np.ndarray:
    """Render white text on a black background at 300×100 px."""
    img = np.zeros((100, 400, 3), dtype=np.uint8)
    img[:] = (255, 255, 255)   # white background
    cv2.putText(
        img, text,
        (20, 70),
        cv2.FONT_HERSHEY_SIMPLEX,
        2.0,
        (0, 0, 0),   # black text
        3,
        cv2.LINE_AA,
    )
    if path:
        cv2.imwrite(path, img)
    return img


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_extract_returns_schema():
    from ocr_extractor import OCRExtractor
    extractor = OCRExtractor(confidence_threshold=0)
    img = make_test_image("Test99")
    result = extractor.extract(img)

    assert "extracted_text" in result,  "Missing 'extracted_text'"
    assert "confidence"     in result,  "Missing 'confidence'"
    assert "low_quality"    in result,  "Missing 'low_quality'"
    assert "bounding_boxes" in result,  "Missing 'bounding_boxes'"
    assert isinstance(result["bounding_boxes"], list)
    print(f"  extracted_text : {result['extracted_text']!r}")
    print(f"  confidence     : {result['confidence']}")
    print(f"  bounding_boxes : {len(result['bounding_boxes'])} tokens")


def test_preprocess_shape():
    from ocr_extractor import OCRExtractor
    extractor = OCRExtractor()
    img = make_test_image()
    processed = extractor.preprocess(img)
    assert processed.ndim == 2, "Preprocessed image must be grayscale (2-D)"
    print(f"  Preprocessed shape: {processed.shape}")


def test_visualize_saves_file():
    from ocr_extractor import OCRExtractor
    extractor = OCRExtractor(confidence_threshold=0)
    img = make_test_image("Viz42")
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        out_path = f.name
    extractor.visualize(img, output_path=out_path)
    assert Path(out_path).exists(), "Annotated image file was not created"
    print(f"  Annotated image saved to: {out_path}")


def test_unsupported_format():
    from ocr_extractor import OCRExtractor
    extractor = OCRExtractor()
    try:
        extractor.extract("file.gif")
        print("  FAIL: expected ValueError")
        return False
    except (ValueError, FileNotFoundError):
        print("  Correctly raised error for unsupported/missing file.")
    return True


def test_blur_detection():
    from ocr_extractor import OCRExtractor
    extractor = OCRExtractor(blur_threshold=500)  # very high threshold
    # A heavily blurred image should be flagged low_quality
    img = make_test_image("Blur")
    blurred = cv2.GaussianBlur(img, (51, 51), 0)
    result = extractor.extract(blurred)
    assert result["low_quality"] is True, "Blurry image was not flagged low_quality"
    print(f"  Blurry image correctly flagged. low_quality={result['low_quality']}")


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

TESTS = [
    test_extract_returns_schema,
    test_preprocess_shape,
    test_visualize_saves_file,
    test_unsupported_format,
    test_blur_detection,
]

if __name__ == "__main__":
    passed = failed = 0
    for test in TESTS:
        print(f"\n[TEST] {test.__name__}")
        try:
            test()
            print("  PASS")
            passed += 1
        except Exception as exc:
            print(f"  FAIL — {exc}")
            failed += 1

    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed")
    sys.exit(0 if failed == 0 else 1)
