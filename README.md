# Water Meter Reading System Backend

This is the Node.js backend for the Water Meter Reading System, designed to receive meter readings (with images) from a Flutter app, process OCR jobs, and generate corresponding water bills.

## Project Structure

- `config/`: Configuration files and environment variables handling.
- `controllers/`: Request handlers for API routes (where the logic sits).
- `routes/`: Express API route definitions.
- `middleware/`: Express middleware functions (auth, error-handling, upload).
- `models/`: Mongoose database schemas.
- `services/`: Business logic and external API integrations (like OCR logic).
- `utils/`: Utility functions and helper methods.
- `workers/`: Background jobs and workers (for offline processing).

## Prerequisites

- Node.js (v18+)
- MongoDB Database (Local or Cloud/Atlas)

## Installation

1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy `.env.example` to `.env` and fill in the values:
   ```bash
   cp .env.example .env
   ```

## Running the Server

- **Development mode** (with nodemon):
  ```bash
  npm run dev
  ```
- **Production mode**:
  ```bash
  npm start
  ```

## API Testing

When running locally, verify the backend works by making a GET request to `http://localhost:3000/`.
