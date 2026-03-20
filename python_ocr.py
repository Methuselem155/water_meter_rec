import sys
import json
import re
import os
from typing import Optional, Tuple
from pathlib import Path

import cv2
import pytesseract
import numpy as np
from PIL import Image

def preprocess_image_for_digits(img: Image.Image) -> Image.Image:
    """Preprocess image to enhance digit visibility using OpenCV."""
    # Convert PIL to cv2
    img_cv = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
    gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
    
    # Resize up
    gray = cv2.resize(gray, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
    
    # Blur and threshold
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    thresh = cv2.adaptiveThreshold(blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
    
    # Morphological closing
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
    
    # Convert back to PIL
    return Image.fromarray(closed)

def preprocess_image_for_ocr(img: Image.Image) -> Image.Image:
    """Preprocess image for improved OCR accuracy using OpenCV."""
    img_cv = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
    gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
    
    # Resize up
    gray = cv2.resize(gray, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)
    
    # Adjust contrast using CLAHE
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
    cl1 = clahe.apply(gray)
    
    # Denoise
    denoised = cv2.medianBlur(cl1, 3)
    
    return Image.fromarray(denoised)


def extract_digits_with_confidence(img: Image.Image) -> Tuple[Optional[str], float]:
    """Extract digits using optimized Tesseract configuration."""
    # Extract digits with improved PSM for meter screens
    config = r'--psm 11 -c tessedit_char_whitelist=0123456789'
    
    data = pytesseract.image_to_data(img, config=config, output_type=pytesseract.Output.DICT)
    
    # Extract text and confidence
    texts = data['text']
    confidences = [float(c) if str(c).replace('.','',1).isdigit() else 0.0 for c in data['conf']]
    valid_entries = [(text, conf) for text, conf in zip(texts, confidences) 
                     if text.strip() and conf > 0]
    
    if not valid_entries:
        return None, 0.0
    
    
    # Concatenate all detected digits
    all_digits = ''.join([text for text, _ in valid_entries])
    avg_confidence = np.mean([conf for _, conf in valid_entries]) / 100.0 if valid_entries else 0.0
    
    # Try to extract the meter reading (usually longest sequence)
    digit_matches = re.findall(r'\d{3,}', all_digits)
    
    if digit_matches:
        digit_matches.sort(key=len, reverse=True)
        # Return exactly the matched string to preserve leading zeros
        reading = digit_matches[0]
        return reading, min(avg_confidence, 1.0)
    
    return None, min(avg_confidence, 1.0)


def extract_data_from_text(text: str) -> dict:
    reading_value: Optional[str] = None
    serial_extracted: Optional[str] = None

    cleaned = re.sub(r"[\r\n]+", " ", text or "").strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    dense = re.sub(r"\s+", "", cleaned)

    # Extract digits: prefer longer sequences but allow any 3+ digits
    matches = re.findall(r"\d{6,10}", dense)
    if not matches:
        matches = re.findall(r"\d{4,10}", dense)
    if not matches:
        matches = re.findall(r"\d{3,}", dense)

    if matches:
        matches.sort(key=len, reverse=True)
        reading_value = matches[0]

    # Serial: 11 mixed chars and digits preferred, but not mandatory
    serial_match = re.search(r"\b[A-Z0-9]{11}\b", cleaned, re.IGNORECASE)
    if not serial_match:
        serial_match = re.search(r"[A-Z0-9]{11}", dense, re.IGNORECASE)
    if not serial_match:
        serial_match = re.search(r"[A-Z0-9]{6,}", cleaned, re.IGNORECASE)

    if serial_match:
        serial_extracted = serial_match.group(0).upper()

    return {
        "readingValue": reading_value,
        "serialNumberExtracted": serial_extracted,
    }


def save_debug_image(img: Image.Image, path: str) -> None:
    """Save preprocessed image for debugging."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    img.save(path)


def main() -> None:
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Missing image path"}))
        sys.exit(1)

    image_path = sys.argv[1]
    debug_mode = len(sys.argv) > 2 and sys.argv[2] == "--debug"

    try:
        # Open original image
        img = Image.open(image_path)
        
        # Preprocess for OCR
        preprocessed_img = preprocess_image_for_ocr(img)
        
        # Run full OCR with standard config
        raw_text = pytesseract.image_to_string(preprocessed_img)
        
        # Extract digits with confidence
        digit_value, confidence = extract_digits_with_confidence(preprocessed_img)
        
        # Extract data from raw text
        data = extract_data_from_text(raw_text)
        
        # Use digit extraction result if available, otherwise use regex extraction
        final_reading = digit_value if digit_value is not None else data["readingValue"]
        
        # Save debug images if requested
        if debug_mode:
            base_name = Path(image_path).stem
            save_debug_image(preprocessed_img, f"tmp/debug_preprocessed_{base_name}.png")
            save_debug_image(preprocess_image_for_digits(img), 
                           f"tmp/debug_digits_{base_name}.png")
        
        result = {
            "readingValue": final_reading,
            "serialNumberExtracted": data["serialNumberExtracted"],
            "confidence": confidence,
            "rawText": raw_text,
        }
        print(json.dumps(result))
    except Exception as exc:
        print(json.dumps({"error": str(exc)}))
        sys.exit(1)


if __name__ == "__main__":
    main()

