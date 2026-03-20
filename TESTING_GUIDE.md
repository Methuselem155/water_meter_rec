# Testing Guide - OCR Fixes

## What Was Fixed
1. ✅ **OCR Confidence Normalization** - Confidence now displays 0-100% instead of 2900%
2. ✅ **Image Path Storage** - Uses relative paths (uploads/filename.jpg) instead of absolute Windows paths
3. ✅ **Image Display** - Images now load properly in the reading detail screen
4. ✅ **OCR Processing** - Worker handles path conversion properly

## Step-by-Step Testing

### Step 1: Restart Backend
```bash
cd c:\Users\Methuselem\water-meter
npm install  # Ensure all dependencies are fresh
node server.js
```

**Expected Output:**
```
Connected to MongoDB
Server is running on port 3000
```

### Step 2: Check Backend is Serving Uploads
Open browser and test:
```
http://192.168.43.233:3000/
```
Should return: `{"message":"Water Meter Backend Server is running."}`

### Step 3: Restart Flutter App
```bash
cd c:\Users\Methuselem\water-meter\water_meter_app
flutter pub get
flutter run
```

### Step 4: Test End-to-End Flow

1. **Login** to the app with your credentials
2. **Navigate to Capture Screen** (Camera tab)
3. **Take a Photo** of a water meter
4. **Confirm Upload** in the confirmation screen
5. **Wait 10-30 seconds** for OCR to process
6. **Check History** tab - should see the new reading
7. **Click on Reading** - image should display and confidence should be 0-100%

### Step 5: Monitor Logs
While testing, watch the backend console for:
```
[OCR Service] Starting image processing for: uploads/...
[OCR Service] Raw Tesseract confidence: XX
[OCR Service] Extracted - Value: XXXX, Serial: ABC123456, Normalized Confidence: 0.XXXX
[OCR Worker] Job completed and saved for reading ID: ...
```

## Troubleshooting

### Issue: Image Not Loading in Reading Details
- Check browser console for network errors
- Verify file exists: `c:\Users\Methuselem\water-meter\uploads\`
- Confirm URL format: `http://192.168.43.233:3000/uploads/filename.jpg`

### Issue: OCR Still Fails
- Check backend logs for file path errors
- Verify image file is actually saved in uploads folder
- Check MongoDB to confirm reading document exists

### Issue:Confidence Still Shows Wrong Value
- Clear app cache and rebuild:
  ```bash
  flutter clean
  flutter pub get
  flutter run
  ```

## Database Verification
If you want to check MongoDB directly:
```javascript
db.readings.findOne({}, {imagePath: 1, confidence: 1, readingValue: 1})

// Expected: 
// imagePath: "uploads/69aa0b214685a04f62fa4b54-1773351989582-656695191.jpg"
// confidence: 0.75  (normalized 0-1 range)
// readingValue: 2345
```

## Success Indicators
- ✅ Image displays in reading detail screen
- ✅ Confidence shows as 0-100% (not 2900%)
- ✅ OCR extracts reading value and serial number
- ✅ Reading appears in history after upload
