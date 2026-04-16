"""
Unit tests for SerialExtractor.

Run:
    python test_serial.py
"""

import sys
import json
import unittest.mock as mock

import cv2
import numpy as np

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def make_serial_image(serial_str: str) -> np.ndarray:
    """Render serial number as white text on black background (400x100 px)."""
    img = np.zeros((100, 400, 3), dtype=np.uint8)
    cv2.putText(
        img,
        serial_str,
        (10, 65),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.2,
        (255, 255, 255),  # white text
        2,
        cv2.LINE_AA,
    )
    return img


# ---------------------------------------------------------------------------
# Task 2 — schema test
# ---------------------------------------------------------------------------

def test_result_schema():
    """extract_serial_number must return dict with correct keys and types."""
    from serial_extractor import SerialExtractor

    extractor = SerialExtractor()
    img = make_serial_image("I20BA008111")

    # Mock _run_ocr_candidates so we don't need a real OCR engine
    fake_bbox = [[10, 10], [200, 10], [200, 50], [10, 50]]
    with mock.patch("serial_extractor._run_ocr_candidates",
                    return_value=[("I20BA008111", 0.95, fake_bbox)]):
        with mock.patch("serial_extractor._localise_serial_region", return_value=None):
            result = extractor.extract_serial_number(img)

    assert isinstance(result, dict), "Result must be a dict"
    assert "serial_number" in result, "Missing key: serial_number"
    assert "confidence" in result, "Missing key: confidence"
    assert "low_quality" in result, "Missing key: low_quality"
    assert "bounding_box" in result, "Missing key: bounding_box"

    assert result["serial_number"] is None or isinstance(result["serial_number"], str), \
        "serial_number must be str or None"
    assert isinstance(result["confidence"], float), "confidence must be float"
    assert isinstance(result["low_quality"], bool), "low_quality must be bool"
    assert result["bounding_box"] is None or isinstance(result["bounding_box"], dict), \
        "bounding_box must be dict or None"

    print(f"  serial_number : {result['serial_number']!r}")
    print(f"  confidence    : {result['confidence']}")
    print(f"  low_quality   : {result['low_quality']}")
    print(f"  bounding_box  : {result['bounding_box']}")


# ---------------------------------------------------------------------------
# Task 2.1 — _validate_pattern tests
# ---------------------------------------------------------------------------

def test_validate_pattern_accepts_valid():
    """Valid serial numbers must pass _validate_pattern."""
    from serial_extractor import _validate_pattern

    assert _validate_pattern("I20BA008111") is True, "I20BA008111 should be valid"
    assert _validate_pattern("I22BA271986") is True, "I22BA271986 should be valid"
    assert _validate_pattern("A00AA000000") is True, "A00AA000000 should be valid"
    assert _validate_pattern("Z99ZZ999999") is True, "Z99ZZ999999 should be valid"
    print("  All valid serials accepted.")


def test_validate_pattern_rejects_invalid():
    """Invalid strings must fail _validate_pattern."""
    from serial_extractor import _validate_pattern

    # Too short
    assert _validate_pattern("I20BA008") is False, "Short string should be rejected"
    # All digits
    assert _validate_pattern("12345678901") is False, "All-digit string should be rejected"
    # Wrong format: starts with digit
    assert _validate_pattern("120BA008111") is False, "Starts with digit should be rejected"
    # Wrong format: digit at position 3
    assert _validate_pattern("I200A008111") is False, "Digit at pos 3 should be rejected"
    # Too long
    assert _validate_pattern("I20BA0081110") is False, "Too long should be rejected"
    # Empty
    assert _validate_pattern("") is False, "Empty string should be rejected"
    # Lowercase
    assert _validate_pattern("i20ba008111") is False, "Lowercase should be rejected"
    print("  All invalid strings rejected.")


# ---------------------------------------------------------------------------
# Task 2.1 — _apply_substitutions tests
# ---------------------------------------------------------------------------

def test_apply_substitutions_corrects_0_and_1():
    """_apply_substitutions must fix 0→O and 1→I at letter positions."""
    from serial_extractor import _apply_substitutions

    # 0 at position 0 (must be letter) → O
    result = _apply_substitutions("020BA008111")
    assert result == "O20BA008111", f"Expected O20BA008111, got {result!r}"

    # 1 at position 0 (must be letter) → I
    result = _apply_substitutions("120BA008111")
    assert result == "I20BA008111", f"Expected I20BA008111, got {result!r}"

    # Already valid — no substitution needed
    result = _apply_substitutions("I20BA008111")
    assert result == "I20BA008111", f"Expected I20BA008111 unchanged, got {result!r}"

    # 1 at position 4 (must be letter) → I
    result = _apply_substitutions("I20B1008111")
    assert result == "I20BI008111", f"Expected I20BI008111, got {result!r}"

    # 0 at position 3 (must be letter) → O
    result = _apply_substitutions("I200A008111")
    assert result == "I20OA008111", f"Expected I20OA008111, got {result!r}"

    # String that can't be fixed — returned unchanged
    result = _apply_substitutions("XXXXXXXXXXX")
    assert result == "XXXXXXXXXXX", f"Unfixable string should be returned unchanged"

    print("  All substitution cases correct.")


# ---------------------------------------------------------------------------
# Task 3.1 — blur detection tests
# ---------------------------------------------------------------------------

def test_blur_detection_flags_low_quality():
    """A heavily blurred image must set low_quality=True with high threshold."""
    from serial_extractor import SerialExtractor

    extractor = SerialExtractor(blur_threshold=500)
    img = make_serial_image("I20BA008111")
    blurred = cv2.GaussianBlur(img, (51, 51), 0)

    with mock.patch("serial_extractor._run_ocr_candidates", return_value=[]):
        with mock.patch("serial_extractor._localise_serial_region", return_value=None):
            result = extractor.extract_serial_number(blurred)

    assert result["low_quality"] is True, \
        f"Blurry image should be flagged low_quality=True, got {result['low_quality']}"
    print(f"  Blurry image correctly flagged. low_quality={result['low_quality']}")


def test_blur_threshold_zero_disables():
    """blur_threshold=0 must always return low_quality=False."""
    from serial_extractor import SerialExtractor

    extractor = SerialExtractor(blur_threshold=0)
    img = make_serial_image("I20BA008111")
    blurred = cv2.GaussianBlur(img, (51, 51), 0)

    with mock.patch("serial_extractor._run_ocr_candidates", return_value=[]):
        with mock.patch("serial_extractor._localise_serial_region", return_value=None):
            result = extractor.extract_serial_number(blurred)

    assert result["low_quality"] is False, \
        f"blur_threshold=0 should disable blur detection, got low_quality={result['low_quality']}"
    print(f"  blur_threshold=0 correctly disables detection. low_quality={result['low_quality']}")


def test_default_blur_threshold():
    """SerialExtractor() must have blur_threshold == 40.0 by default."""
    from serial_extractor import SerialExtractor

    extractor = SerialExtractor()
    assert extractor.blur_threshold == 40.0, \
        f"Default blur_threshold should be 40.0, got {extractor.blur_threshold}"
    print(f"  Default blur_threshold = {extractor.blur_threshold}")


# ---------------------------------------------------------------------------
# Task 4.1 — region hint tests
# ---------------------------------------------------------------------------

def test_region_hint_empty_region():
    """region_hint pointing to a 1x1 corner with no text must return serial_number=None."""
    from serial_extractor import SerialExtractor

    extractor = SerialExtractor()
    img = make_serial_image("I20BA008111")

    # Point to a 1x1 region in the top-left corner — no text there
    region_hint = {"x": 0, "y": 0, "width": 1, "height": 1}

    with mock.patch("serial_extractor._run_ocr_candidates", return_value=[]):
        result = extractor.extract_serial_number(img, region_hint=region_hint)

    assert result["serial_number"] is None, \
        f"Empty region should return serial_number=None, got {result['serial_number']!r}"
    print(f"  Empty region correctly returns serial_number=None")


def test_region_hint_out_of_bounds_no_raise():
    """Out-of-bounds region_hint must be clamped without raising an exception."""
    from serial_extractor import SerialExtractor

    extractor = SerialExtractor()
    img = make_serial_image("I20BA008111")

    # Negative coordinates, well outside image bounds
    region_hint = {"x": -100, "y": -100, "width": 50, "height": 50}

    try:
        with mock.patch("serial_extractor._run_ocr_candidates", return_value=[]):
            result = extractor.extract_serial_number(img, region_hint=region_hint)
        print(f"  Out-of-bounds region_hint handled gracefully. serial_number={result['serial_number']!r}")
    except Exception as exc:
        raise AssertionError(f"Out-of-bounds region_hint raised an exception: {exc}") from exc


# ---------------------------------------------------------------------------
# Task 6.1 — CLI tests
# ---------------------------------------------------------------------------

def test_cli_serial_flag():
    """--serial flag must produce JSON output with a 'serial_number' key."""
    import io
    from ocr import main

    fake_serial_result = {
        "serial_number": "I20BA008111",
        "confidence": 0.95,
        "low_quality": False,
        "bounding_box": None,
    }
    fake_bgr = np.zeros((100, 400, 3), dtype=np.uint8)

    with mock.patch("serial_extractor._load_image", return_value=fake_bgr):
        with mock.patch("ocr_extractor._load_image", return_value=fake_bgr):
            with mock.patch(
                "serial_extractor.SerialExtractor.extract_serial_number",
                return_value=fake_serial_result,
            ):
                captured = io.StringIO()
                with mock.patch("sys.stdout", captured):
                    try:
                        main(["--image", "fake.jpg", "--serial"])
                    except SystemExit as exc:
                        if exc.code not in (0, None):
                            raise

    output = captured.getvalue()
    parsed = json.loads(output)
    assert "serial_number" in parsed, f"Expected 'serial_number' key in output, got: {parsed}"
    print(f"  serial_number: {parsed['serial_number']!r}")


def test_cli_combined_meter_serial():
    """--meter --serial must produce combined JSON with both 'meter_reading' and 'serial_number' keys."""
    import io
    from ocr import main

    fake_meter_result = {
        "reading": "00123.456",
        "low_quality": False,
        "bounding_boxes": [],
    }
    fake_serial_result = {
        "serial_number": "I20BA008111",
        "confidence": 0.95,
        "low_quality": False,
        "bounding_box": None,
    }
    fake_bgr = np.zeros((100, 400, 3), dtype=np.uint8)

    with mock.patch("serial_extractor._load_image", return_value=fake_bgr):
        with mock.patch("ocr_extractor._load_image", return_value=fake_bgr):
            with mock.patch(
                "ocr_extractor.OCRExtractor.extract_meter_reading",
                return_value=fake_meter_result,
            ):
                with mock.patch(
                    "serial_extractor.SerialExtractor.extract_serial_number",
                    return_value=fake_serial_result,
                ):
                    captured = io.StringIO()
                    with mock.patch("sys.stdout", captured):
                        try:
                            main(["--image", "fake.jpg", "--meter", "--serial"])
                        except SystemExit as exc:
                            if exc.code not in (0, None):
                                raise

    output = captured.getvalue()
    parsed = json.loads(output)
    assert "meter_reading" in parsed, f"Expected 'meter_reading' key in output, got: {parsed}"
    assert "serial_number" in parsed, f"Expected 'serial_number' key in output, got: {parsed}"
    print(f"  meter_reading: {parsed['meter_reading']!r}")
    print(f"  serial_number: {parsed['serial_number']!r}")


def test_cli_exit_code_3():
    """When serial_number is None, main() must raise SystemExit(3)."""
    import io
    from ocr import main

    fake_serial_result = {
        "serial_number": None,
        "confidence": 0.0,
        "low_quality": False,
        "bounding_box": None,
    }
    fake_bgr = np.zeros((100, 400, 3), dtype=np.uint8)

    with mock.patch("serial_extractor._load_image", return_value=fake_bgr):
        with mock.patch("ocr_extractor._load_image", return_value=fake_bgr):
            with mock.patch(
                "serial_extractor.SerialExtractor.extract_serial_number",
                return_value=fake_serial_result,
            ):
                captured = io.StringIO()
                with mock.patch("sys.stdout", captured):
                    try:
                        main(["--image", "fake.jpg", "--serial"])
                        raise AssertionError("Expected SystemExit(3) but no exception was raised")
                    except SystemExit as exc:
                        assert exc.code == 3, f"Expected exit code 3, got {exc.code}"
                        print(f"  Correctly raised SystemExit(3)")


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

TESTS = [
    test_result_schema,
    test_validate_pattern_accepts_valid,
    test_validate_pattern_rejects_invalid,
    test_apply_substitutions_corrects_0_and_1,
    test_blur_detection_flags_low_quality,
    test_blur_threshold_zero_disables,
    test_default_blur_threshold,
    test_region_hint_empty_region,
    test_region_hint_out_of_bounds_no_raise,
    test_cli_serial_flag,
    test_cli_combined_meter_serial,
    test_cli_exit_code_3,
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
