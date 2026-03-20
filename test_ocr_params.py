import sys
import glob
from PIL import Image, ImageEnhance, ImageFilter, ImageOps
import pytesseract
import numpy as np
import re

def process_test(img, prefix, psm_list):
    # Try different enhancements
    # 1. Base Grayscale
    gray = img.convert('L')
    
    # 2. Binarized (Threshold)
    threshold = 150
    bin_img = gray.point(lambda p: 0 if p < threshold else 255, '1').convert('L')
    
    # 3. High Contrast
    enhancer = ImageEnhance.Contrast(gray)
    contrast = enhancer.enhance(3.0)
    
    # 4. Sharpen
    enhancer2 = ImageEnhance.Sharpness(contrast)
    sharp = enhancer2.enhance(3.0)

    images = {
        'gray': gray,
        'binarized': bin_img,
        'high_contrast': contrast,
        'sharp': sharp
    }

    for name, processed_img in images.items():
        for psm in psm_list:
            config = f'--psm {psm} -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            text = pytesseract.image_to_string(processed_img, config=config)
            cleaned = re.sub(r'[\r\n]+', ' ', text).strip()
            if len(cleaned) > 5:
                print(f"[{prefix}] | [{name}] | [PSM {psm}]: {cleaned}")


def main():
    images = glob.glob('uploads/*.jpg') + glob.glob('uploads/*.png')
    for img_path in images[:3]:  # test first 3
        try:
            img = Image.open(img_path)
            print(f"\n--- Testing {img_path} ---")
            process_test(img, img_path, [3, 6, 11, 12])
        except Exception as e:
            print(f"Error on {img_path}: {e}")

if __name__ == '__main__':
    main()
