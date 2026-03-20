import sys
from PIL import Image
import pytesseract

img = Image.open(sys.argv[1])
data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
print(data.keys())
