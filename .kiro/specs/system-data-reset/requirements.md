# Requirements Document

## Introduction

This feature provides a system-wide data reset capability for the water utility management system. An admin can clear all non-admin user accounts, meters, readings, and bills from the database through the admin dashboard. After the reset, the system must be in a clean state where new users, meters, readings, and bills can be created and immediately reflected in the admin dashboard.

## Glossary

- **Admin**: An authenticated user with `role: 'admin'` in the system.
- **System_Reset_API**: The backend Express endpoint responsible for executing the data reset operation.
- **Admin_Dashboard**: The React frontend application used by admins to manage the water utility system.
- **Non-Admin_User**: A User document with `role: 'user'`.
- **Reset_Confirmation**: A required explicit confirmation step before the reset is executed, to prevent accidental data loss.
- **Clean_State**: The system state after a reset where all readings, bills, meters, and non-admin users have been deleted and counts return to zero.

---

## Requirements

### Requirement 1: Admin-Only Reset Endpoint

**User Story:** As an admin, I want a secure API endpoint to reset all system data, so that I can clear the database without direct database access.

#### Acceptance Criteria

1. THE System_Reset_API SHALL be accessible only to authenticated users with `role: 'admin'`.
2. WHEN an unauthenticated request is made to the reset endpoint, THE System_Reset_API SHALL return an HTTP 401 response.
3. WHEN an authenticated non-admin user requests a reset, THE System_Reset_API SHALL return an HTTP 403 response.

---

### Requirement 2: Complete Data Clearance

**User Story:** As an admin, I want the reset to remove all readings, bills, meters, and non-admin users, so that the system starts from a clean state.

#### Acceptance Criteria

1. WHEN a reset is triggered, THE System_Reset_API SHALL delete all documents in the `readings` collection.
2. WHEN a reset is triggered, THE System_Reset_API SHALL delete all documents in the `bills` collection.
3. WHEN a reset is triggered, THE System_Reset_API SHALL delete all documents in the `meters` collection.
4. WHEN a reset is triggered, THE System_Reset_API SHALL delete all Non-Admin_User documents from the `users` collection.
5. WHEN a reset is triggered, THE System_Reset_API SHALL preserve all documents in the `users` collection where `role` is `'admin'`.
6. WHEN the reset completes, THE System_Reset_API SHALL return a success response containing the count of deleted documents per collection.

---

### Requirement 3: Reset Confirmation in Admin Dashboard

**User Story:** As an admin, I want a confirmation step before the reset executes, so that accidental data loss is prevented.

#### Acceptance Criteria

1. THE Admin_Dashboard SHALL provide a "System Reset" action accessible from the Dashboard page.
2. WHEN an admin initiates a reset, THE Admin_Dashboard SHALL display a Reset_Confirmation dialog requiring explicit acknowledgment before proceeding.
3. WHEN an admin cancels the Reset_Confirmation dialog, THE Admin_Dashboard SHALL not call the reset endpoint and the system data SHALL remain unchanged.
4. WHEN an admin confirms the Reset_Confirmation dialog, THE Admin_Dashboard SHALL call the reset endpoint and display a loading indicator until the operation completes.

---

### Requirement 4: Post-Reset Dashboard Refresh

**User Story:** As an admin, I want the dashboard to reflect the cleared state immediately after a reset, so that I can confirm the operation succeeded.

#### Acceptance Criteria

1. WHEN the reset operation completes successfully, THE Admin_Dashboard SHALL refresh all displayed statistics to reflect the Clean_State (zero counts).
2. WHEN the reset operation completes successfully, THE Admin_Dashboard SHALL display a success notification to the admin.
3. IF the reset operation fails, THEN THE Admin_Dashboard SHALL display an error notification with a descriptive message and SHALL NOT refresh the statistics.

---

### Requirement 5: Post-Reset Data Integrity

**User Story:** As an admin, I want new users and readings created after a reset to appear correctly in the dashboard, so that the system operates normally after clearing.

#### Acceptance Criteria

1. WHEN a new Non-Admin_User is created after a reset, THE Admin_Dashboard SHALL display the new user in the Users page.
2. WHEN a new reading is submitted after a reset, THE Admin_Dashboard SHALL display the new reading in the Readings page.
3. WHEN a new bill is generated after a reset, THE Admin_Dashboard SHALL display the new bill in the Bills page.
4. WHILE the system is in Clean_State, THE System_Reset_API stats endpoint SHALL return zero for `totalUsers`, `totalMeters`, `totalReadings`, and `totalBills`.
