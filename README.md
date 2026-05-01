# Water Meter Reading System

An end-to-end smart water meter management platform built for WASAC (Rwanda). It combines a Flutter mobile app, a Node.js REST API backend, an admin web dashboard, and Claude Vision AI to automatically read water meter digits and serial numbers from photos.

---

## System Overview

```
Flutter Mobile App
      │  (photo upload via REST API)
      ▼
Node.js Backend (Express + MongoDB)
      │  (spawns Python subprocess)
      ▼
python_ocr.py  ──►  Claude Vision API (claude-sonnet-4-6)
      │  (returns JSON: reading + serial + confidence)
      ▼
Validation Service  ──►  Billing Service
      │
      ▼
MongoDB  ◄──  Admin Dashboard (React + Vite)
```

---

## Repository Structure

```
water-meter/
├── server.js                  # Express app entry point
├── python_ocr.py              # Claude Vision OCR entry point
├── python_ocr_server.py       # Persistent HTTP OCR server (optional)
│
├── config/
│   └── tariffs.js             # WASAC tariff rates by customer category
│
├── controllers/
│   ├── authController.js      # Register / login / profile
│   ├── readingController.js   # Upload, scan, list readings
│   ├── billController.js      # Fetch bills
│   └── adminController.js     # Admin CRUD operations
│
├── middleware/
│   ├── authMiddleware.js      # JWT verification
│   ├── adminMiddleware.js     # Admin role guard
│   ├── uploadMiddleware.js    # Multer — saves images to ocr_model/
│   └── errorHandler.js        # Global error handler
│
├── models/
│   ├── User.js                # Account, category, role
│   ├── Meter.js               # Serial number, status, owner
│   ├── Reading.js             # OCR result, validation status
│   └── Bill.js                # Consumption, tariff bands, amount
│
├── routes/
│   ├── authRoutes.js
│   ├── readingRoutes.js
│   ├── billRoutes.js
│   └── adminRoutes.js
│
├── services/
│   ├── ocrService.js          # Spawns python_ocr.py subprocess
│   ├── validationService.js   # Serial + progression checks
│   └── billingService.js      # Tariff calculation + bill generation
│
├── workers/
│   └── ocrWorker.js           # Async OCR job runner
│
├── ocr_model/                 # Uploaded meter images (auto-created)
│
├── admin-dashboard/           # React + Vite admin web UI
│
└── water_meter_app/           # Flutter mobile application
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter 3, Riverpod, Dio, Hive, Camera |
| Backend API | Node.js 18+, Express 4, Mongoose 8 |
| Database | MongoDB 6 |
| OCR Engine | Claude Vision API (claude-sonnet-4-6) |
| OCR Bridge | Python 3, anthropic SDK, Pillow |
| Admin UI | React 18, Vite, Axios |
| Auth | JWT (jsonwebtoken + bcrypt) |
| Containerization | Docker + Docker Compose |

---

## Prerequisites

- Node.js v18+
- Python 3.9+
- MongoDB (local or Atlas)
- Anthropic API key — get one at https://console.anthropic.com/settings/keys
- Flutter SDK 3.11+ (for mobile app)

---

## Backend Setup

### 1. Install Node dependencies

```bash
npm install
```

### 2. Install Python dependencies

```bash
pip install anthropic pillow
```

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
PORT=3000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/water-meter
JWT_SECRET=your_strong_random_secret
JWT_EXPIRE=7d
ANTHROPIC_API_KEY=sk-ant-api03-...
OCR_SERVER_PORT=5001
```

### 4. Run the server

```bash
# Development (auto-reload)
npm run dev

# Production
npm start
```

Server starts on `http://localhost:3000`.

### 5. Create the first admin account

```bash
node createAdmin.js
```

---

## Docker Setup

```bash
docker-compose up --build
```

This starts the Node.js backend on port 3000 and MongoDB on port 27017.

> Note: Add `ANTHROPIC_API_KEY` to the `environment` section in `docker-compose.yml` before running.

---

## OCR Pipeline

When a meter image is uploaded:

1. Image is saved to `ocr_model/<userId-timestamp.jpg>`
2. `ocrWorker.js` calls `ocrService.js`
3. `ocrService.js` spawns: `python python_ocr.py <imagePath> --mode auto`
4. `python_ocr.py` loads `.env`, compresses the image if > 4 MB, then sends it to Claude Vision API
5. Claude returns a JSON with `full_reading`, `main_digits`, `decimal_digits`, `serial_number`, `confidence`
6. Result is saved to the Reading document in MongoDB
7. `validationService.js` checks serial number match and reading progression
8. If validated, `billingService.js` generates a bill using WASAC tariff rates

### Test OCR manually

```bash
python python_ocr.py ocr_model/sample.jpg --mode auto
```

Expected output:
```json
{
  "readingValue": 1054.669,
  "integerPart": "01054",
  "fractionPart": "669",
  "serialNumberExtracted": "I20BA008111",
  "confidence": 0.95,
  "rawText": "01054.669",
  "ocrEngine": "claude-vision",
  "success": true
}
```

---

## REST API Reference

Base URL: `http://localhost:3000/api`

### Authentication

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/auth/register` | Register user + link meter | Public |
| POST | `/auth/login` | Login with phone or account number | Public |
| GET | `/auth/me` | Get current user profile | JWT |

**Register body:**
```json
{
  "accountNumber": "ACC001",
  "fullName": "John Doe",
  "phoneNumber": "+250788000000",
  "password": "secret123",
  "meterSerialNumber": "I20BA008111",
  "category": "RESIDENTIAL"
}
```

**Login body:**
```json
{ "phoneNumber": "+250788000000", "password": "secret123" }
```

---

### Readings

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/readings/upload` | Upload full meter image | JWT |
| POST | `/readings/scan` | Upload display + serial crops | JWT |
| GET | `/readings` | List user's readings (paginated) | JWT |
| GET | `/readings/:id` | Get single reading with bill | JWT |

**Upload query params:**
- `?awaitOcr=true` — wait for OCR to complete before responding (default: async)

---

### Bills

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/bills` | List user's bills | JWT |
| GET | `/bills/:id` | Get single bill detail | JWT |

---

### Admin

All admin routes require `role: admin` JWT.

| Method | Endpoint | Description |
|---|---|---|
| GET | `/admin/stats` | Dashboard stats |
| GET | `/admin/users` | List all users |
| POST | `/admin/users` | Create user |
| DELETE | `/admin/users/:id` | Delete user |
| GET | `/admin/meters` | List all meters |
| GET | `/admin/readings` | List all readings |
| PUT | `/admin/readings/:id/status` | Update reading status |
| DELETE | `/admin/readings/:id` | Delete reading |
| GET | `/admin/bills` | List all bills |
| PATCH | `/admin/bills/:id/confirm-payment` | Mark bill as paid |
| PATCH | `/admin/bills/mark-overdue` | Bulk mark overdue bills |
| GET | `/admin/bills/summary` | Billing summary stats |

---

## Tariff Structure (WASAC Rwanda)

VAT rate: 18%

| Category | Type | Rate |
|---|---|---|
| PUBLIC TAP | Flat | 323 RWF/m³ |
| RESIDENTIAL | Progressive | 340 → 720 → 845 → 877 RWF/m³ |
| NON RESIDENTIAL | Progressive | 877 → 895 RWF/m³ |
| INDUSTRIES | Flat | 736 RWF/m³ |

Residential progressive bands: 0–5 m³, 5–20 m³, 20–50 m³, 50+ m³.

---

## Validation Rules

A reading is validated if:

1. A reading value was successfully extracted (not null)
2. The extracted serial number matches the registered meter serial (fuzzy match ≥ 70% similarity, tolerating OCR substitutions like O/0)
3. The reading value is not less than the previous validated reading (logical progression check)

Possible statuses: `pending` → `validated` / `failed` / `fraud_suspected`

---

## Mobile App (Flutter)

Located in `water_meter_app/`.

### Features

- Camera capture with green guide frame (auto-crops to frame before upload)
- Claude Vision AI extracts meter reading + serial number in one shot
- Offline queue — readings captured without internet sync automatically when reconnected
- Reading history with validation status and bill details
- JWT authentication with secure token storage

### Setup

```bash
cd water_meter_app
flutter pub get
flutter run
```

Update the API base URL in `lib/core/constants.dart` to point to your backend.

---

## Admin Dashboard (React)

Located in `admin-dashboard/`.

```bash
cd admin-dashboard
npm install
npm run dev
```

Runs on `http://localhost:5173`. Update the API URL in `src/services/api.js`.

### Features

- User and meter management
- Reading review and manual status override
- Bill management and payment confirmation
- System statistics overview

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `PORT` | No | Server port (default: 3000) |
| `NODE_ENV` | No | `development` or `production` |
| `MONGODB_URI` | Yes | MongoDB connection string |
| `JWT_SECRET` | Yes | Secret for signing JWT tokens |
| `JWT_EXPIRE` | No | Token expiry (default: 7d) |
| `ANTHROPIC_API_KEY` | Yes | Claude Vision API key |
| `OCR_SERVER_PORT` | No | Persistent OCR server port (default: 5001) |
| `ALLOWED_ORIGINS` | No | Comma-separated CORS origins (empty = allow all) |
| `PYTHON_OCR_CMD` | No | Python executable path (default: `python` on Windows, `python3` on Linux) |
