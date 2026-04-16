# Implementation Plan: Serial Number Extraction

## Overview

Implement `SerialExtractor` in a new `serial_extractor.py`, wire it into `ocr.py` (CLI) and `app.py` (Gradio UI), and cover it with unit tests and Hypothesis property-based tests in `test_serial.py`.

## Tasks

- [x] 1. Create `serial_extractor.py` with core helpers and `SerialExtractor` class
  - Import `_load_image`, `_blur_score`, `_get_easy_reader` from `ocr_extractor.py`
  - Implement `_apply_substitutions(text)`: replace `0→O` and `1→I` at letter positions (0, 3, 4) only when the substituted string matches the pattern and the original does not
  - Implement `_validate_pattern(text)`: return `True` if text matches `[A-Z][0-9]{2}[A-Z]{2}[0-9]{6}`
  - Implement `_localise_serial_region(bgr)`: run EasyOCR with no allowlist, filter large-text detections (`height > image_height * 0.05`, `len(text) >= 6`) outside the digit-drum zone (central 60% width, lower 50% height), return `(x1, y1, x2, y2)` crop or `None`
  - Implement `_run_ocr_candidates(bgr_crop)`: try EasyOCR with alphanumeric allowlist; fall back to Tesseract `--psm 11` with alphanumeric whitelist if EasyOCR unavailable; return list of `(text, confidence, bbox)` tuples
  - Implement `SerialExtractor.__init__(blur_threshold=40.0)`
  - Implement `SerialExtractor.extract_serial_number(image, region_hint=None)`: load image, compute blur/low_quality, apply region_hint or auto-localise, run OCR candidates, apply substitutions, validate pattern, return highest-confidence match or null result
  - Return dict with keys `serial_number`, `confidence`, `low_quality`, `bounding_box`
  - Handle `region_hint` out-of-bounds by clamping to image dimensions with a warning log
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 7.1, 7.2_

  - [ ]* 1.1 Write property test for result schema invariant
    - **Property 1: Result schema invariant**
    - **Validates: Requirements 1.1, 1.2, 8.1**
    - Generate random BGR arrays; assert result always has keys `serial_number`, `confidence`, `low_quality`, `bounding_box` with correct types

  - [ ]* 1.2 Write property test for JSON round-trip
    - **Property 9: JSON round-trip**
    - **Validates: Requirements 7.1, 7.2**
    - Generate valid result dicts; assert `json.loads(json.dumps(result)) == result`

- [x] 2. Implement pattern validation and OCR substitution unit tests
  - [x] 2.1 Write unit tests for `_validate_pattern` and `_apply_substitutions`
    - Test that valid serials (e.g. `I20BA008111`) pass `_validate_pattern`
    - Test that invalid strings are rejected
    - Test that `0→O` / `1→I` substitution at letter positions produces a match
    - _Requirements: 2.1, 2.2, 2.4_

  - [ ]* 2.2 Write property test for pattern acceptance
    - **Property 2: Pattern acceptance**
    - **Validates: Requirements 2.1**
    - Generate strings matching `[A-Z][0-9]{2}[A-Z]{2}[0-9]{6}`; mock OCR to return them; assert `serial_number` equals the generated string

  - [ ]* 2.3 Write property test for pattern rejection
    - **Property 3: Pattern rejection**
    - **Validates: Requirements 2.2, 8.2**
    - Generate strings that do not match and cannot be fixed by substitution; mock OCR; assert `serial_number is None` and `confidence == 0.0`

  - [ ]* 2.4 Write property test for substitution enables match
    - **Property 5: Substitution enables match**
    - **Validates: Requirements 2.4**
    - Generate strings that only match after `0→O`/`1→I` substitution; mock OCR; assert `serial_number` equals the corrected string

  - [ ]* 2.5 Write property test for highest-confidence candidate wins
    - **Property 4: Highest-confidence candidate wins**
    - **Validates: Requirements 2.3**
    - Generate multiple valid candidates with distinct confidence scores; mock OCR; assert returned serial matches the highest-confidence candidate

- [x] 3. Implement blur detection unit tests and property tests
  - [x] 3.1 Write unit tests for blur detection
    - Test that a synthetically blurred image sets `low_quality=true` (default threshold 40.0)
    - Test that `blur_threshold=0` always returns `low_quality=false`
    - Test that `SerialExtractor()` has `blur_threshold == 40.0`
    - _Requirements: 4.1, 4.2, 4.3, 8.3_

  - [ ]* 3.2 Write property test for blur detection threshold
    - **Property 6: Blur detection threshold**
    - **Validates: Requirements 4.1, 8.3**
    - For random thresholds > 40.0, create a blurry image with Laplacian variance below threshold; assert `low_quality=true`

  - [ ]* 3.3 Write property test for disabled blur detection
    - **Property 7: Disabled blur detection**
    - **Validates: Requirements 4.2**
    - With `blur_threshold=0`, assert `low_quality=false` for any random image

- [x] 4. Implement region hint unit tests and property test
  - [x] 4.1 Write unit test for region hint
    - Test that a `region_hint` pointing to an empty region returns `serial_number=null`
    - Test that out-of-bounds `region_hint` is clamped without raising
    - _Requirements: 3.3_

  - [ ]* 4.2 Write property test for region hint constrains OCR
    - **Property 8: Region hint constrains OCR**
    - **Validates: Requirements 3.3**
    - Provide a region hint that does not overlap the serial number; assert `serial_number is None`

- [x] 5. Checkpoint — ensure all `test_serial.py` tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Add `hypothesis` to `requirements.txt` and update CLI in `ocr.py`
  - Add `hypothesis>=6.0.0` to `requirements.txt`
  - Add `easyocr>=1.6.0` to `requirements.txt` if not already present
  - Add `--serial` argument to `parse_args()` in `ocr.py`
  - In `main()`: when `--serial` is set, instantiate `SerialExtractor` and call `extract_serial_number(args.image)`
  - When both `--meter` and `--serial` are set, run both independently and return combined JSON with keys `meter_reading` and `serial_number`
  - Exit with code `3` when `serial_number` is `null` (takes priority over exit code `2`)
  - _Requirements: 5.1, 5.2, 5.3_

  - [x] 6.1 Write unit tests for CLI `--serial` flag
    - Test `--serial` flag produces JSON with `serial_number` key
    - Test `--meter --serial` combined output has both `meter_reading` and `serial_number` keys
    - Test exit code `3` when `serial_number` is null
    - _Requirements: 5.1, 5.2, 5.3_

- [x] 7. Update `app.py` to show serial number in Gradio UI
  - Add `serial_output` Textbox (label "Serial Number", `interactive=False`, placeholder "e.g. I20BA008111") to the right column, below `reading_output`
  - Import `SerialExtractor` at the top of `app.py`
  - In `run_ocr()`: add `serial_output` to the return tuple; when `meter_mode` is `True`, call `SerialExtractor(blur_threshold=blur_threshold).extract_serial_number(bgr)` and set `serial_display` to the result or `"Not detected"` when null; when `meter_mode` is `False`, set `serial_display` to `""`
  - Wire `serial_output` into `run_btn.click` outputs list
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 8. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- `ocr_extractor.py` and `test_ocr.py` MUST NOT be modified
- Property tests use `hypothesis` with a minimum of 100 examples each
- Each property test is tagged: `# Feature: serial-number-extraction, Property N: <text>`
- Exit code precedence in `ocr.py`: `3` (serial null) > `2` (low quality) > `0`
