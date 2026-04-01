# EasyOCR Text Extractor

A beginner-friendly Python OCR pipeline that extracts text and numeric digits from JPG/PNG images using EasyOCR and OpenCV.

## Requirements

- Python 3.8+
- easyocr >= 1.7.0
- opencv-python >= 4.8.0
- numpy >= 1.24.0
- hypothesis >= 6.0.0 (for property-based tests)
- pytest >= 7.0.0 (for running tests)

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### CLI

```bash
python ocr_extractor.py --image sample.jpg
python ocr_extractor.py --image scan.png --resize 1.5 --output results.txt
python ocr_extractor.py --image photo.jpg --visualize --save-annotated
```

Available arguments:

| Argument          | Default       | Description                                      |
|-------------------|---------------|--------------------------------------------------|
| `--image`         | *(required)*  | Path to input image (.jpg / .jpeg / .png)        |
| `--languages`     | `en`          | One or more EasyOCR language codes               |
| `--resize`        | `1.0`         | Scale factor before OCR (e.g. 1.5 to upscale)   |
| `--output`        | `results.txt` | Output .txt file path                            |
| `--visualize`     | off           | Display image with bounding boxes                |
| `--save-annotated`| off           | Save the annotated image to disk                 |

### Python API

```python
from ocr_extractor import run_ocr_pipeline, ProcessingConfig

config = ProcessingConfig(
    image_path="sample.jpg",
    languages=["en"],
    resize_factor=1.5,
    output_path="results.txt",
    visualize=False,
    save_annotated=False,
)

full_text, digits = run_ocr_pipeline(config)
print(f"Extracted text : {full_text}")
print(f"Digits only    : {digits}")
```

## Output

Results are printed to the console and saved to the specified `.txt` file:

```
=== OCR Results ===
Full text : Invoice 1042 Total 99.50 USD
Digits    : 1042 99 50
===================
```

The `.txt` file contains both the full extracted text and the digit-only sequences.

## Running Tests

```bash
python -m pytest tests/ -v --tb=short
```
