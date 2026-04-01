# Implementation Plan: EasyOCR Text Extractor

## Overview

Implement a single-script Python OCR pipeline (`ocr_extractor.py`) that preprocesses images with OpenCV, extracts text and digits via EasyOCR, and outputs results to console and a `.txt` file, with optional bounding-box visualization.

## Tasks

- [ ] 1. Set up project structure and dependencies
  - Create `ocr_extractor.py` as the main module
  - Create `requirements.txt` with easyocr>=1.7.0, opencv-python>=4.8.0, numpy>=1.24.0
  - Create `tests/` directory with `__init__.py` and `conftest.py`
  - Define `ProcessingConfig` dataclass with all fields and validation rules
  - _Requirements: ProcessingConfig data model, validation rules_

- [ ] 2. Implement InputValidator
  - [ ] 2.1 Implement `validate_image(image_path: str) -> str`
    - Check file existence with `os.path.abspath` + `os.path.exists`
    - Enforce `.jpg`, `.jpeg`, `.png` extensions
    - Raise `FileNotFoundError` or `ValueError` on failure
    - Return resolved absolute path on success
    - _Requirements: InputValidator component, Error Scenarios 1 & 2_

- [ ] 3. Implement Preprocessor
  - [ ] 3.1 Implement `preprocess(image_path: str, resize_factor: float = 1.0) -> np.ndarray`
    - Load with `cv2.imread`; raise `ValueError` if result is `None` (Error Scenario 3)
    - Convert BGR → Grayscale
    - Optionally resize when `resize_factor != 1.0`
    - Apply `cv2.GaussianBlur` with kernel `(5, 5)`
    - Apply `cv2.adaptiveThreshold` (ADAPTIVE_THRESH_GAUSSIAN_C, blockSize=11, C=2)
    - Return 2D uint8 NumPy array
    - _Requirements: Preprocessor component, Preprocessing Algorithm_

- [ ] 4. Implement TextProcessor
  - [ ] 4.1 Implement `combine_text(ocr_results: list[tuple]) -> str`
    - Join text fragments from `(bbox, text, conf)` tuples with a space separator
    - Return empty string for empty input
    - _Requirements: TextProcessor component, combine_text spec_

  - [ ] 4.2 Implement `extract_digits(text: str) -> str`
    - Use `re.findall(r'\d+', text)` to isolate numeric sequences
    - Join matches with a space separator
    - Return `""` if no digits found
    - _Requirements: TextProcessor component, Digit Extraction Algorithm_

- [ ] 5. Implement OCREngine
  - [ ] 5.1 Implement `OCREngine` class
    - `__init__` initialises `easyocr.Reader(languages)` exactly once
    - `extract(image)` calls `reader.readtext(image)` and returns raw results
    - _Requirements: OCREngine component_

- [ ] 6. Implement OutputHandler
  - [ ] 6.1 Implement `print_results(full_text: str, digits: str) -> None`
    - Print labelled output to stdout
    - _Requirements: OutputHandler component_

  - [ ] 6.2 Implement `save_results(full_text: str, digits: str, output_path: str) -> None`
    - Write UTF-8 encoded `.txt` file with both sections
    - Catch `PermissionError`, print warning, skip save (Error Scenario 5)
    - _Requirements: OutputHandler component, Error Scenario 5_

- [ ] 7. Implement Visualizer
  - [ ] 7.1 Implement `draw_bounding_boxes(image, ocr_results) -> np.ndarray`
    - Draw `cv2.rectangle` and `cv2.putText` for each bbox on a copy of the image
    - Return annotated image without modifying the original
    - _Requirements: Visualizer component_

  - [ ] 7.2 Implement `show_image` and `save_image`
    - `show_image`: display with `cv2.imshow` / `cv2.waitKey`
    - `save_image`: write to disk with `cv2.imwrite`
    - _Requirements: Visualizer component_

- [ ] 8. Wire pipeline together in `run_ocr_pipeline` and `__main__`
  - [ ] 8.1 Implement `run_ocr_pipeline(config: ProcessingConfig) -> tuple[str, str]`
    - Orchestrate: validate → preprocess → OCR → text processing → output → optional visualize
    - Follow the Main Pipeline Algorithm exactly
    - _Requirements: Main Pipeline Algorithm, all components_

  - [ ] 8.2 Add `__main__` block with `argparse`
    - Arguments: `--image`, `--languages`, `--resize`, `--output`, `--visualize`, `--save-annotated`
    - Build `ProcessingConfig` from args and call `run_ocr_pipeline`
    - _Requirements: Example Usage (CLI)_

- [ ] 9. Write tests
  - [ ] 9.1 Write unit tests for all components
  - [ ] 9.2 Write property-based tests using hypothesis

- [ ] 10. Create README with setup instructions and example usage
