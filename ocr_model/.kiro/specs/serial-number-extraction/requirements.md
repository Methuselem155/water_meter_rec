# Requirements Document

## Introduction

This feature adds serial number extraction to the existing meter OCR project. Utility meters display a serial number (e.g. "I20BA008111") as large alphanumeric text printed on the meter body, in a region physically separate from the digit-drum display used for meter readings. The new extraction model must operate independently of the existing `extract_meter_reading()` logic and must not modify it.

Serial numbers observed in sample images follow the pattern: one letter, two digits, two letters, six digits (total 11 characters), e.g. `I20BA008111`, `I22BA271986`.

## Glossary

- **Serial_Extractor**: The new module/class responsible solely for extracting the meter serial number from an image.
- **OCRExtractor**: The existing class in `ocr_extractor.py` — its methods MUST NOT be modified.
- **Serial_Number**: An alphanumeric identifier printed on the meter body, distinct from the meter reading display. Follows the pattern `[A-Z][0-9]{2}[A-Z]{2}[0-9]{6}` (11 characters).
- **Serial_Region**: The area of the meter image that contains the serial number text, located above or below the digit-drum display.
- **Candidate**: A raw OCR detection result before validation against the serial number pattern.
- **Confidence_Score**: A float in [0.0, 1.0] representing the OCR engine's certainty for a detected string.

---

## Requirements

### Requirement 1: Serial Number Extraction Model

**User Story:** As a developer, I want a dedicated serial number extractor, so that I can obtain the meter serial number without touching the existing meter reading logic.

#### Acceptance Criteria

1. THE Serial_Extractor SHALL expose an `extract_serial_number(image)` method that accepts a file path, base64 string, or numpy BGR array — the same input types accepted by OCRExtractor.
2. WHEN `extract_serial_number` is called, THE Serial_Extractor SHALL return a dict containing at minimum: `serial_number` (str), `confidence` (float), `low_quality` (bool), and `bounding_box` (dict or None).
3. THE Serial_Extractor SHALL be implemented in a new file (`serial_extractor.py`) and MUST NOT modify `ocr_extractor.py`, `app.py`, `ocr.py`, or `test_ocr.py`.

---

### Requirement 2: Serial Number Pattern Validation

**User Story:** As a developer, I want extracted serial numbers validated against the known format, so that garbage OCR output is not returned as a valid serial number.

#### Acceptance Criteria

1. WHEN a Candidate matches the pattern `[A-Z][0-9]{2}[A-Z]{2}[0-9]{6}`, THE Serial_Extractor SHALL return it as the `serial_number` value.
2. WHEN no Candidate matches the pattern, THE Serial_Extractor SHALL return `serial_number` as `null` and set `confidence` to `0.0`.
3. WHEN multiple Candidates match the pattern, THE Serial_Extractor SHALL return the Candidate with the highest Confidence_Score.
4. THE Serial_Extractor SHALL apply common OCR substitution corrections before validation (e.g. digit `0` → letter `O`, digit `1` → letter `I`) when the substitution produces a pattern match and the original does not.

---

### Requirement 3: Region Localisation

**User Story:** As a developer, I want the extractor to focus on the serial number region of the image, so that digit-drum noise does not interfere with serial number detection.

#### Acceptance Criteria

1. WHEN processing a meter image, THE Serial_Extractor SHALL attempt to locate the Serial_Region by searching for a horizontal band of large alphanumeric text outside the digit-drum display area.
2. IF the Serial_Region cannot be localised automatically, THEN THE Serial_Extractor SHALL fall back to running OCR on the full image.
3. WHERE a `region_hint` parameter is provided (a dict with `x`, `y`, `width`, `height`), THE Serial_Extractor SHALL restrict OCR to that region instead of auto-detecting.

---

### Requirement 4: Image Quality Assessment

**User Story:** As a developer, I want the extractor to flag low-quality images, so that unreliable results are clearly communicated to callers.

#### Acceptance Criteria

1. WHEN the Laplacian variance of the input image is below the configured `blur_threshold`, THE Serial_Extractor SHALL set `low_quality` to `true` in the result.
2. WHILE `blur_threshold` is set to `0`, THE Serial_Extractor SHALL skip blur detection and always set `low_quality` to `false`.
3. THE Serial_Extractor SHALL accept a `blur_threshold` constructor parameter with a default value of `40.0`.

---

### Requirement 5: CLI Integration

**User Story:** As a developer, I want to invoke serial number extraction from the command line, so that I can test and use it without writing Python code.

#### Acceptance Criteria

1. WHEN `--serial` flag is passed to `ocr.py`, THE CLI SHALL call `Serial_Extractor.extract_serial_number()` and print the JSON result.
2. WHEN both `--meter` and `--serial` flags are passed, THE CLI SHALL run both extractions independently and return a combined JSON result containing both `meter_reading` and `serial_number` keys.
3. IF the extracted `serial_number` is `null`, THEN THE CLI SHALL exit with code `3` to signal extraction failure.

---

### Requirement 6: Gradio UI Integration

**User Story:** As a user, I want to see the serial number alongside the meter reading in the web UI, so that I can verify both values from a single image upload.

#### Acceptance Criteria

1. WHEN `app.py` is running and Meter Mode is enabled, THE UI SHALL display a "Serial Number" output field alongside the existing meter reading field.
2. WHEN an image is submitted in Meter Mode, THE UI SHALL call `Serial_Extractor.extract_serial_number()` independently and populate the Serial Number field.
3. IF `serial_number` is `null`, THEN THE UI SHALL display "Not detected" in the Serial Number field.

---

### Requirement 7: Serialisation Round-Trip

**User Story:** As a developer, I want the result dict to be JSON-serialisable, so that callers can reliably encode and decode results.

#### Acceptance Criteria

1. THE Serial_Extractor SHALL return only JSON-serialisable types in the result dict (str, float, bool, dict, None).
2. FOR ALL valid result dicts produced by `extract_serial_number`, serialising to JSON and deserialising SHALL produce an equivalent dict (round-trip property).

---

### Requirement 8: Smoke Tests

**User Story:** As a developer, I want automated tests for the serial extractor, so that regressions are caught early.

#### Acceptance Criteria

1. THE test suite SHALL include a test that verifies the result dict schema (keys: `serial_number`, `confidence`, `low_quality`, `bounding_box`).
2. THE test suite SHALL include a test that verifies pattern validation rejects strings that do not match `[A-Z][0-9]{2}[A-Z]{2}[0-9]{6}`.
3. THE test suite SHALL include a test that verifies a blurry synthetic image sets `low_quality` to `true`.
4. THE test suite SHALL be added to a new file `test_serial.py` and MUST NOT modify `test_ocr.py`.
