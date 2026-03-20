import cv2
import pytesseract
import glob
import os
import re

def process_with_cv2(img_path):
    print(f"\n--- Testing CV2 pipeline on {os.path.basename(img_path)} ---")
    img = cv2.imread(img_path)
    if img is None:
        print("Failed to read image")
        return
        
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # 1. Standard blur + Otsu
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh_otsu = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    # 2. Adaptive Thresholding
    thresh_adapt = cv2.adaptiveThreshold(blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
    
    # Text on meters is sometimes light on dark background. Tesseract needs black text on white.
    # Invert images to test both
    inv_otsu = cv2.bitwise_not(thresh_otsu)
    inv_adapt = cv2.bitwise_not(thresh_adapt)
    
    # 3. Morphological closing to thicken segments
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    closed_otsu = cv2.morphologyEx(thresh_otsu, cv2.MORPH_CLOSE, kernel)
    closed_adpt = cv2.morphologyEx(thresh_adapt, cv2.MORPH_CLOSE, kernel)
    
    images = {
        'Gray': gray,
        'Otsu': thresh_otsu,
        'Adaptive': thresh_adapt,
        'Inv_Adaptive': inv_adapt,
        'Closed_Otsu': closed_otsu,
        'Closed_Adapt': closed_adpt
    }
    
    for name, processed_img in images.items():
        # Using PSM 11 (Sparse text) and PSM 6 (Uniform block)
        for psm in [6, 11, 12]:
            config = f'--psm {psm} -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
            text = pytesseract.image_to_string(processed_img, config=config)
            cleaned = re.sub(r'[\r\n]+', ' ', text).strip()
            if len(cleaned) > 5:
                print(f"[{name}] [PSM {psm}]: {cleaned}")

def main():
    images = glob.glob('uploads/*.jpg') + glob.glob('uploads/*.png')
    for img_path in images[:3]:
        process_with_cv2(img_path)

if __name__ == '__main__':
    main()
