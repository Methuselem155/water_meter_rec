"""
ocr_extractor.py
================
A beginner-friendly, single-file OCR pipeline using EasyOCR and OpenCV.

Supports:
  - JPG and PNG images
  - Text extraction and digit-only extraction
  - Optional bounding-box visualisation
  - Console and .txt file output
  - Windows-compatible paths

Usage (Python API):
    from ocr_extractor import run_ocr_pipeline, ProcessingConfig
    config = ProcessingConfig(image_path="sample.jpg", ...)
    full_text, digits = run_ocr_pipeline(config)

Usage (CLI):
    python ocr_extractor.py --image sample.jpg --output results.txt
"""

# ---------------------------------------------------------------------------
# Standard library imports
# ---------------------------------------------------------------------------
import os
import re
import argparse
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Third-party imports
# ---------------------------------------------------------------------------
import cv2
import numpy as np

# easyocr is imported lazily inside OCREngine.__init__ to avoid slow startup
# when the module is imported just for utility functions.


# ---------------------------------------------------------------------------
# Data Model
# ---------------------------------------------------------------------------

@dataclass
class ProcessingConfig:
    """
    Configuration for a single OCR pipeline run.

    Fields
    ------
    image_path     : Path to the input image (.jpg / .jpeg / .png).
    languages      : List of EasyOCR language codes (default: ["en"]).
    resize_factor  : Scale factor applied before OCR (1.0 = no resize).
                     Must be in the range (0.0, 5.0].
    output_path    : Destination path for the results .txt file.
    visualize      : If True, draw bounding boxes on the original image.
    save_annotated : If True (and visualize=True), save the annotated image.
    """
    image_path: str
    languages: list = field(default_factory=lambda: ["en"])
    resize_factor: float = 1.0
    output_path: str = "results.txt"
    visualize: bool = False
    save_annotated: bool = False


# ---------------------------------------------------------------------------
# Component 1: InputValidator
# ---------------------------------------------------------------------------

def validate_image(image_path: str) -> str:
    """
    Validate that *image_path* exists on disk and has a supported extension.

    Parameters
    ----------
    image_path : str
        Path to the image file (relative or absolute).

    Returns
    -------
    str
        Resolved absolute path to the image.

    Raises
    ------
    FileNotFoundError
        If the file does not exist at the resolved path.
    ValueError
        If the file extension is not .jpg, .jpeg, or .png.
    """
    # Resolve to an absolute path so downstream code always gets a full path
    abs_path = os.path.abspath(image_path)

    # Check the file actually exists on disk
    if not os.path.exists(abs_path):
        raise FileNotFoundError(
            f"Image file not found: '{abs_path}'. "
            "Please check the path and try again."
        )

    # Enforce supported extensions (case-insensitive)
    supported = {".jpg", ".jpeg", ".png"}
    _, ext = os.path.splitext(abs_path)
    if ext.lower() not in supported:
        raise ValueError(
            f"Unsupported format '{ext}'. Use JPG or PNG."
        )

    return abs_path


# ---------------------------------------------------------------------------
# Component 2: Preprocessor
# ---------------------------------------------------------------------------

def preprocess(image_path: str, resize_factor: float = 1.0) -> np.ndarray:
    """
    Load an image and apply a preprocessing pipeline to improve OCR accuracy.

    Steps applied (in order):
      1. Load image with cv2.imread
      2. Convert BGR → Grayscale
      3. Optionally resize (when resize_factor != 1.0)
      4. Gaussian blur  (kernel 5×5) to reduce noise
      5. Adaptive threshold to produce a clean binary image

    Parameters
    ----------
    image_path    : str   – Path to a readable image file.
    resize_factor : float – Scale factor; 1.0 means no resize.

    Returns
    -------
    np.ndarray
        2-D uint8 array with pixel values 0 or 255.

    Raises
    ------
    ValueError
        If cv2.imread returns None (corrupt file or unreadable path).
    """
    # Step 1: Load the image from disk
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(
            f"Cannot read image at '{image_path}'. "
            "The file may be corrupt or inaccessible."
        )

    # Step 2: Convert colour image to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Step 3: Optional resize
    if resize_factor != 1.0:
        h, w = gray.shape
        new_w = int(w * resize_factor)
        new_h = int(h * resize_factor)
        gray = cv2.resize(gray, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

    # Step 4: Gaussian blur to smooth out noise before thresholding
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Step 5: Adaptive threshold – converts to a clean black-and-white image.
    #   ADAPTIVE_THRESH_GAUSSIAN_C uses a weighted sum of the neighbourhood.
    #   blockSize=11 means each pixel is compared to its 11×11 neighbourhood.
    #   C=2 is a constant subtracted from the mean to fine-tune the threshold.
    processed = cv2.adaptiveThreshold(
        blurred,
        maxValue=255,
        adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        thresholdType=cv2.THRESH_BINARY,
        blockSize=11,
        C=2,
    )

    return processed


# ---------------------------------------------------------------------------
# Component 3: TextProcessor
# ---------------------------------------------------------------------------

def combine_text(ocr_results: list) -> str:
    """
    Join all text fragments from EasyOCR results into a single string.

    EasyOCR returns a list of (bbox, text, confidence) tuples.
    This function extracts the *text* field from each tuple and joins
    them with a single space.

    Parameters
    ----------
    ocr_results : list of (bbox, text, confidence) tuples

    Returns
    -------
    str
        All detected text fragments joined by spaces.
        Returns "" if *ocr_results* is empty.
    """
    if not ocr_results:
        return ""

    # Each result is a tuple: (bbox, text, confidence)
    # We only need the text (index 1)
    fragments = [result[1] for result in ocr_results]
    return " ".join(fragments)


def extract_digits(text: str) -> str:
    """
    Extract all numeric sequences from *text* using a regular expression.

    For example:
        "Invoice 1042 Total 99.50 USD"  →  "1042 99 50"

    Note: decimal points are NOT included; "99.50" yields "99" and "50"
    as separate matches because the regex matches digit runs only.

    Parameters
    ----------
    text : str – Any string (may be empty).

    Returns
    -------
    str
        Digit sequences separated by spaces, or "" if none found.
    """
    if not text:
        return ""

    # re.findall returns a list of all non-overlapping matches
    matches = re.findall(r'\d+', text)
    return " ".join(matches)


# ---------------------------------------------------------------------------
# Component 4: OCREngine
# ---------------------------------------------------------------------------

class OCREngine:
    """
    Thin wrapper around EasyOCR that initialises the reader exactly once.

    Initialising EasyOCR can take 2–5 seconds because it loads a neural
    network model. By keeping the reader as an instance attribute, you can
    call extract() many times without paying that cost again.

    Parameters
    ----------
    languages : list of str
        EasyOCR language codes, e.g. ["en"] or ["en", "fr"].
    """

    def __init__(self, languages: list = None) -> None:
        if languages is None:
            languages = ["en"]

        # Import here so that importing this module doesn't trigger the slow
        # EasyOCR initialisation unless an OCREngine is actually created.
        import easyocr  # noqa: PLC0415

        # This line downloads model weights on first run (~100 MB).
        # Subsequent runs use the cached weights.
        self.reader = easyocr.Reader(languages)

    def extract(self, image: np.ndarray) -> list:
        """
        Run OCR on a preprocessed image.

        Parameters
        ----------
        image : np.ndarray
            A 2-D (grayscale) or 3-D (BGR) NumPy array.

        Returns
        -------
        list of (bbox, text, confidence) tuples
            May be empty if no text is detected.
        """
        return self.reader.readtext(image)


# ---------------------------------------------------------------------------
# Component 5: OutputHandler
# ---------------------------------------------------------------------------

def print_results(full_text: str, digits: str) -> None:
    """
    Print the OCR results to the console in a readable format.

    Parameters
    ----------
    full_text : str – All detected text joined by spaces.
    digits    : str – Digit-only sequences extracted from full_text.
    """
    print("\n=== OCR Results ===")
    print(f"Full text : {full_text if full_text else '(no text detected)'}")
    print(f"Digits    : {digits if digits else '(no digits detected)'}")
    print("===================\n")


def save_results(full_text: str, digits: str, output_path: str) -> None:
    """
    Write the OCR results to a UTF-8 encoded .txt file.

    If the file cannot be written due to a permission error, a warning is
    printed to the console and the save is skipped gracefully.

    Parameters
    ----------
    full_text   : str – All detected text.
    digits      : str – Digit-only sequences.
    output_path : str – Destination file path (should end with .txt).
    """
    try:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write("=== OCR Results ===\n")
            f.write(f"Full text:\n{full_text}\n\n")
            f.write(f"Digits only:\n{digits}\n")
        print(f"Results saved to: {output_path}")
    except PermissionError:
        print(
            f"Warning: Cannot write to '{output_path}'. "
            "Permission denied – results not saved."
        )


# ---------------------------------------------------------------------------
# Component 6: Visualizer
# ---------------------------------------------------------------------------

def draw_bounding_boxes(image: np.ndarray, ocr_results: list) -> np.ndarray:
    """
    Draw bounding boxes and text labels on a *copy* of the image.

    Each EasyOCR result contains a bounding box defined by four corner
    points: [[x1,y1],[x2,y1],[x2,y2],[x1,y2]].  This function draws a
    green rectangle and the detected text above each box.

    Parameters
    ----------
    image       : np.ndarray – Original image (BGR, 3-channel).
    ocr_results : list       – EasyOCR (bbox, text, confidence) tuples.

    Returns
    -------
    np.ndarray
        Annotated copy of the image; the original is not modified.
    """
    # Work on a copy so the original image is never modified
    annotated = image.copy()

    for bbox, text, confidence in ocr_results:
        # bbox is [[x1,y1],[x2,y1],[x2,y2],[x1,y2]]
        # We only need the top-left and bottom-right corners for a rectangle
        x1 = int(bbox[0][0])
        y1 = int(bbox[0][1])
        x2 = int(bbox[2][0])
        y2 = int(bbox[2][1])

        # Draw a green rectangle around the detected text region
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color=(0, 255, 0), thickness=2)

        # Put the detected text just above the rectangle
        label = f"{text} ({confidence:.2f})"
        cv2.putText(
            annotated,
            label,
            org=(x1, max(y1 - 5, 0)),   # slightly above the box
            fontFace=cv2.FONT_HERSHEY_SIMPLEX,
            fontScale=0.5,
            color=(0, 255, 0),
            thickness=1,
            lineType=cv2.LINE_AA,
        )

    return annotated


def show_image(image: np.ndarray, window_title: str = "OCR Result") -> None:
    """
    Display an image in an OpenCV window.

    The window stays open until the user presses any key.

    Parameters
    ----------
    image        : np.ndarray – Image to display.
    window_title : str        – Title shown in the window title bar.
    """
    cv2.imshow(window_title, image)
    cv2.waitKey(0)          # 0 = wait indefinitely for a key press
    cv2.destroyAllWindows()


def save_image(image: np.ndarray, output_path: str) -> None:
    """
    Save an annotated image to disk.

    Parameters
    ----------
    image       : np.ndarray – Image to save.
    output_path : str        – Destination file path (e.g. "annotated.png").
    """
    cv2.imwrite(output_path, image)
    print(f"Annotated image saved to: {output_path}")


# ---------------------------------------------------------------------------
# Main Pipeline
# ---------------------------------------------------------------------------

def _build_image_variants(image_path: str, resize_factor: float) -> list:
    """
    Build a list of image variants to try for OCR, from least to most processed.

    EasyOCR performs best on natural images; heavy thresholding can hurt.
    We try variants in order and use whichever yields the most detections.
    """
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"Cannot read image at '{image_path}'.")

    variants = []

    # Variant 1: original colour image (best for most photos)
    if resize_factor != 1.0:
        h, w = image.shape[:2]
        image = cv2.resize(image, (int(w * resize_factor), int(h * resize_factor)),
                           interpolation=cv2.INTER_LINEAR)
    variants.append(("original colour", image))

    # Variant 2: grayscale only
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    variants.append(("grayscale", gray))

    # Variant 3: grayscale + light denoise (no threshold)
    denoised = cv2.GaussianBlur(gray, (3, 3), 0)
    variants.append(("denoised grayscale", denoised))

    # Variant 4: full preprocessing with adaptive threshold (original pipeline)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    thresholded = cv2.adaptiveThreshold(
        blurred, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2,
    )
    variants.append(("adaptive threshold", thresholded))

    return variants


def run_ocr_pipeline(config: ProcessingConfig) -> tuple:
    """
    Orchestrate the full OCR pipeline from image path to text output.

    Pipeline stages
    ---------------
    1. Validate  – check the image path and extension.
    2. Preprocess – build image variants (colour, gray, denoised, thresholded).
    3. OCR        – try each variant; keep the one with the most detections.
    4. Text proc  – combine fragments; extract digits.
    5. Output     – print to console; save to .txt file.
    6. Visualize  – (optional) draw bounding boxes; display / save.

    Parameters
    ----------
    config : ProcessingConfig

    Returns
    -------
    tuple[str, str]
        (full_text, digits)
    """
    # ------------------------------------------------------------------
    # Stage 1: Validate input
    # ------------------------------------------------------------------
    validated_path = validate_image(config.image_path)

    # Keep the original colour image for visualisation
    original_image = cv2.imread(validated_path)

    # ------------------------------------------------------------------
    # Stage 2 + 3: Try multiple image variants, pick best OCR result
    # ------------------------------------------------------------------
    engine = OCREngine(languages=config.languages)
    variants = _build_image_variants(validated_path, config.resize_factor)

    best_results = []
    best_variant = "none"
    for variant_name, img in variants:
        results = engine.extract(img)
        if len(results) > len(best_results):
            best_results = results
            best_variant = variant_name
        if best_results:
            # Already found something — only keep trying if still empty
            # (avoid unnecessary OCR passes once we have detections)
            pass

    ocr_results = best_results
    if ocr_results:
        print(f"[OCR] Best result from variant: '{best_variant}' "
              f"({len(ocr_results)} region(s) detected)")
    else:
        print("Warning: No text detected in the image. "
              "Try a higher --resize value or a clearer image.")

    # ------------------------------------------------------------------
    # Stage 4: Text processing
    # ------------------------------------------------------------------
    full_text = combine_text(ocr_results)
    digits = extract_digits(full_text)

    # ------------------------------------------------------------------
    # Stage 5: Output
    # ------------------------------------------------------------------
    print_results(full_text, digits)
    save_results(full_text, digits, config.output_path)

    # ------------------------------------------------------------------
    # Stage 6: Visualisation (optional) — always uses original colour image
    # ------------------------------------------------------------------
    if config.visualize and original_image is not None:
        annotated = draw_bounding_boxes(original_image, ocr_results)

        if config.save_annotated:
            # Derive annotated image path from the output path
            base, _ = os.path.splitext(config.output_path)
            annotated_path = base + "_annotated.png"
            save_image(annotated, annotated_path)

        show_image(annotated, window_title="OCR Result")

    return full_text, digits


# ---------------------------------------------------------------------------
# CLI Entry Point
# ---------------------------------------------------------------------------

def _build_arg_parser() -> argparse.ArgumentParser:
    """Build and return the argument parser for the CLI."""
    parser = argparse.ArgumentParser(
        prog="ocr_extractor",
        description="Extract text and digits from an image using EasyOCR.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python ocr_extractor.py --image sample.jpg\n"
            "  python ocr_extractor.py --image scan.png --resize 1.5 --output out.txt\n"
            "  python ocr_extractor.py --image photo.jpg --visualize --save-annotated\n"
        ),
    )

    parser.add_argument(
        "--image",
        required=True,
        metavar="PATH",
        help="Path to the input image (.jpg / .jpeg / .png).",
    )
    parser.add_argument(
        "--languages",
        nargs="+",
        default=["en"],
        metavar="LANG",
        help="One or more EasyOCR language codes (default: en).",
    )
    parser.add_argument(
        "--resize",
        type=float,
        default=1.0,
        metavar="FACTOR",
        help="Resize factor before OCR (e.g. 1.5 to upscale). Default: 1.0.",
    )
    parser.add_argument(
        "--output",
        default="results.txt",
        metavar="PATH",
        help="Output .txt file path (default: results.txt).",
    )
    parser.add_argument(
        "--visualize",
        action="store_true",
        help="Display the image with bounding boxes drawn.",
    )
    parser.add_argument(
        "--save-annotated",
        action="store_true",
        dest="save_annotated",
        help="Save the annotated image alongside the output .txt file.",
    )

    return parser


if __name__ == "__main__":
    parser = _build_arg_parser()
    args = parser.parse_args()

    config = ProcessingConfig(
        image_path=args.image,
        languages=args.languages,
        resize_factor=args.resize,
        output_path=args.output,
        visualize=args.visualize,
        save_annotated=args.save_annotated,
    )

    run_ocr_pipeline(config)
