# OCR Model Fixes - Testing Guide

## Issues Fixed

### 1. **Tesseract Worker Initialization**
- Fixed: Tesseract wasn't properly initialized with the Worker API
- Solution: Used `Tesseract.createWorker()` with proper language initialization
- Added: Logging for worker initialization and status

### 2. **Graceful Shutdown**
- Added: Proper cleanup of Tesseract workers on server shutdown
- Prevents: Memory leaks and hung processes
- Added: Signal handlers for SIGTERM and SIGINT

### 3. **Better Error Logging**
- Added: Detailed logging of Tesseract output and confidence scores
- Saves: Preprocessed debug images to `tmp/` folder for inspection
- Shows: Raw text extracted before pattern matching

### 4. **Flexible Extraction**
- Made: Digit and serial patterns more flexible
- Now tries: Multiple regex patterns with fallbacks
- Handles: Various meter formats and orientations

## Testing the Fixed OCR

### Step 1: Start Fresh Backend
```bash
cd c:\Users\Methuselem\water-meter

# Stop any running processes (Ctrl+C)

# Start the server
node server.js
```

**Expected Output:**
```
Connected to MongoDB
Server is running on port 3000
```

### Step 2: Test OCR Directly (Optional)
If you have an existing meter image, test OCR without the full app:

```bash
node test-ocr.js uploads/69aa0b214685a04f62fa4b54-1773351989582-656695191.jpg
```

This will output:
```
========================================
Testing OCR with image: uploads/...
========================================

[OCR Service] Starting image processing for: ...
[OCR Service] Image preprocessed, buffer size: XXXX bytes
[Tesseract] loading: XX%
[OCR Service] Running Tesseract recognition...
[Tesseract] recognizing: XX%

========================================
OCR Results:
========================================
Reading Value: 2345 (or NOT EXTRACTED)
Serial Number: ABC123456 (or NOT EXTRACTED)
Confidence: 75.23%
Raw Text:
[Full text extracted by OCR]
```

### Step 3: Test Full App Flow
1. **Restart Flutter app**:
   ```bash
   cd c:\Users\Methuselem\water-meter\water_meter_app
   flutter run
   ```

2. **Capture and upload** a meter photo

3. **Monitor logs** in backend console:
   - Look for: `[OCR Service] Starting image processing`
   - Look for: `[OCR Service] Raw Tesseract text output`
   - Look for: `[OCR Service] Extraction complete`

4. **Check History tab** in app within 20-30 seconds

## Debugging OCR Issues

### Check Preprocessed Images
After each upload, debug preprocessed images are saved to:
```
c:\Users\Methuselem\water-meter\tmp\debug_preprocessed_*.jpg
```

These show what Tesseract actually sees. If digits don't look clear:
- Adjust `brightness` (currently 1.2)
- Adjust `contrast` (currently 1.3)
- Adjust `threshold` (currently 150)

### Common Issues

**Issue: Empty extraction (null values)**
- Check: Backend console for "No text extracted from image (empty result)"
- Fix: Adjust preprocessing parameters in ocrService.js
- Try: Taking clearer photos with better lighting

**Issue: Wrong digit extraction**
- Check: Debug preprocessed image in `tmp/` folder
- Try: Increasing threshold value if digits look faint
- Try: Increasing contrast if image is washed out

**Issue: Worker initialization fails**
- Check: Backend console for "Failed to initialize Tesseract worker"
- Fix: Wait 10-30 seconds on first run (Tesseract downloads ~50MB model)
- Try: Restart backend if timeout occurs

## Key Files Modified

1. **services/ocrService.js**
   - Proper Tesseract worker initialization
   - Enhanced logging
   - Flexible extraction patterns

2. **server.js**
   - Graceful shutdown handling
   - Tesseract worker cleanup

3. **services/validationService.js**
   - Lenient serial number validation
   - Doesn't fail on missing serial

4. **New: test-ocr.js**
   - Standalone OCR testing tool

## Next Steps

1. Run the backend with new code
2. Try the test script first to debug OCR output
3. Test full app flow
4. If still failing, check preprocessed debug images
5. Adjust preprocessing parameters if needed

Remember: First Tesseract run downloads ~50MB model - be patient!
