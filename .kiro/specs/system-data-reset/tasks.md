# Implementation Plan: System Data Reset

## Overview

Add a secure admin-only reset endpoint to the Express backend and a confirmation-gated reset action to the React admin dashboard. The backend deletes all readings, bills, meters, and non-admin users in one operation and returns deletion counts. The frontend shows a confirmation dialog, calls the endpoint, then refreshes stats and notifies the admin.

## Tasks

- [x] 1. Add `resetSystem` controller function to `controllers/adminController.js`
  - [x] 1.1 Implement `resetSystem` that deletes all Reading, Bill, Meter documents and all User documents where `role !== 'admin'` using `deleteMany`
  - Return a JSON response with `{ success: true, data: { deletedReadings, deletedBills, deletedMeters, deletedUsers } }`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ]* 1.2 Write unit tests for `resetSystem` controller
    - Mock Mongoose models and verify each `deleteMany` is called with correct filter
    - Verify response shape includes per-collection deleted counts
    - Verify admin users are preserved (filter `{ role: { $ne: 'admin' } }`)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 2. Register the reset route in `routes/adminRoutes.js`
  - Add `router.post('/reset', adminMiddleware, adminController.resetSystem)`
  - _Requirements: 1.1, 1.2, 1.3_

  - [ ]* 2.1 Write unit tests for route-level auth guards
    - Verify unauthenticated request returns HTTP 401 (handled by `authMiddleware`)
    - Verify authenticated non-admin request returns HTTP 403 (handled by `adminMiddleware`)
    - _Requirements: 1.1, 1.2, 1.3_

- [x] 3. Checkpoint — Ensure all backend tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Add `resetSystem` API call to `admin-dashboard/src/services/api.js`
  - Export a `resetSystem` function that calls `POST /admin/reset` via the existing `api` axios instance
  - _Requirements: 3.4_

- [x] 5. Add reset UI to `admin-dashboard/src/pages/Dashboard.jsx`
  - [x] 5.1 Add a "System Reset" button to the Dashboard page
    - Place the button in the existing activity overview panel
    - _Requirements: 3.1_

  - [x] 5.2 Implement confirmation dialog
    - On button click, show a modal/dialog asking the admin to confirm before proceeding
    - Provide "Cancel" and "Confirm Reset" actions
    - _Requirements: 3.2, 3.3_

  - [x] 5.3 Wire confirm action to the API call with loading state
    - On confirm, set a loading indicator and call `resetSystem()` from `api.js`
    - Disable the confirm button while loading to prevent double-submission
    - _Requirements: 3.4_

  - [x] 5.4 Handle success: refresh stats and show success notification
    - On success, re-fetch `/admin/stats` to update all stat cards to zero counts
    - Display a success notification (toast or inline message) to the admin
    - _Requirements: 4.1, 4.2_

  - [x] 5.5 Handle error: show error notification without refreshing stats
    - On failure, display an error notification with the message from the API response
    - Do not update stat cards on failure
    - _Requirements: 4.3_

  - [ ]* 5.6 Write unit tests for Dashboard reset flow
    - Test that cancel does not call the reset API
    - Test that confirm calls the API and triggers stat refresh on success
    - Test that an API error shows the error notification and leaves stats unchanged
    - _Requirements: 3.3, 4.1, 4.2, 4.3_

- [x] 6. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- `adminMiddleware` already chains `authMiddleware` + role check, so auth/403 guards are automatic
- The stats refresh after reset satisfies Requirement 5.4 (zero counts in clean state) implicitly via the existing `/admin/stats` endpoint
- Property tests are not included here because the reset logic is deterministic deletion with no complex invariants; unit tests with mocked models are the appropriate coverage
