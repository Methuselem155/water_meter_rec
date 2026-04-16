import anthropic
import base64
import json

API_KEY = "your_api_key_here"
IMAGE_PATH = "sample1.jpg"

with open(IMAGE_PATH, "rb") as f:
    image_data = base64.b64encode(f.read()).decode("utf-8")

ext = IMAGE_PATH.split(".")[-1].lower()
media_type = "image/jpeg" if ext in ["jpg", "jpeg"] else f"image/{ext}"

client = anthropic.Anthropic(api_key=API_KEY)

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=600,
    messages=[{
        "role": "user",
        "content": [
            {
                "type": "image",
                "source": {"type": "base64", "media_type": media_type, "data": image_data}
            },
            {
                "type": "text",
                "text": """Extract from this water meter image and return ONLY this JSON:
{
  "full_reading": "01001.39",
  "main_digits": "01001",
  "decimal_digits": "39",
  "unit": "m3",
  "serial_number": "I20BA008111",
  "brand": "Itron",
  "confidence": 92,
  "notes": ""
}
Black/dark background = main digits. Red/pink background = decimal digits."""
            }
        ]
    }]
)

result_text = response.content[0].text.strip()
if "```" in result_text:
    result_text = result_text.split("```")[1].lstrip("json").strip()

result = json.loads(result_text)

print(f"Full Reading  : {result['full_reading']} {result['unit']}")
print(f"Main Digits   : {result['main_digits']}")
print(f"Decimal Digits: {result['decimal_digits']}")
print(f"Serial Number : {result['serial_number']}")
print(f"Brand         : {result['brand']}")
print(f"Confidence    : {result['confidence']}%")
print(f"Notes         : {result['notes']}")