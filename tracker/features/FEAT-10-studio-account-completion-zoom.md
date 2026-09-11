# FEAT-10: Studio Onboarding, Account Completion & Zoom Video Integration

## Feature Overview
Provides a comprehensive multi-step account onboarding and completion flow for newly registered studios, sets Account Completion as the default landing view upon registration and login until completed, captures all operational, location, GST, and bank payout parameters ("Thanks/Bank Details"), integrates Zoom OAuth & Server-to-Server live classroom authentication, automatically creates authenticated Zoom meeting rooms (`https://us05web.zoom.us/j/...`) for newly provisioned class batches, and displays all verified values under the Studio Profiler & Settings view.

---

## What Was Implemented

### 1. Database Schema Expansion & Migration
- **File**: `progressrooms-api/app/models/organization.py`
- **Migration**: `progressrooms-api/alembic/versions/002_studio_profile_and_zoom.py`
- Added 26 fields to `OrganizationSetting`:
  - Contact & Brand: `phone`, `studio_tagline`, `disciplines`
  - Location & Delivery: `teaching_mode` (`PHYSICAL`, `ONLINE`, `HYBRID`), `address_line1`, `address_line2`, `city`, `state`, `pincode`, `country`
  - Legal & Tax: `has_gst`, `gst_number`, `legal_business_name`, `pan_number`
  - Bank Payouts ("Thanks"): `bank_name`, `account_holder_name`, `account_number_enc`, `ifsc_code`, `upi_id`, `settlement_cycle`
  - Zoom Authentication: `zoom_account_email`, `zoom_auto_meeting_enabled`, `zoom_waiting_room`, `zoom_host_video`
  - Progress Tracking: `account_completed` (bool), `completion_step` (int)

### 2. Backend REST API Endpoints
- **File**: `progressrooms-api/app/modules/organizations/router.py`
  - `GET /api/v1/organizations/{org_id}/profile`: Returns full sanctuary profile with masked bank account (`••••••••1234`), GST verification, and Zoom integration status.
  - `PUT /api/v1/organizations/{org_id}/profile`: Updates profile across wizard steps with validation.
  - `POST /api/v1/organizations/{org_id}/zoom/connect`: Authenticates Zoom credentials/OAuth, stores encrypted credentials in `organization_integrations`.
  - `POST /api/v1/organizations/{org_id}/zoom/disconnect`: Deactivates Zoom integration.
  - `POST /api/v1/organizations/{org_id}/zoom/generate-meeting`: Generates live authenticated Zoom meeting structures.
- **File**: `progressrooms-api/app/modules/auth/service.py` & `router.py`:
  - `register_user`: Initializes `OrganizationSetting` (`account_completed=False`, `completion_step=1`).
  - `login_with_password` & `verify_otp`: Return `account_completed`, `completion_step`, and `zoom_connected` in the user payload.

### 3. Frontend Multi-Step Wizard & Default Landing Page
- **File**: `progressrooms-web/src/app/(dashboard)/dashboard/page.tsx`
  - **Left Sidebar Navigation**: Added "Account Completion" item with live badge (`Setup Req.` when pending, `✓ Done` when completed).
  - **Default Landing**: If `!user.account_completed`, newly registered or logged-in studios automatically land on the Account Completion tab.
  - **5-Step Setup Wizard**:
    1. Studio Profile & Primary Mobile Phone (with WhatsApp preference)
    2. Teaching Location (Physical/Online/Hybrid) & Optional GST Number (GSTIN + Legal Name + PAN)
    3. Bank & Payout Configuration (The "Thanks" perspective: Bank Name, Account Holder, Account Number with confirmation, IFSC, UPI ID, Settlement Cycle)
    4. Zoom Live Video Authentication (One-Click OAuth or Server-to-Server credentials, auto-meeting creation toggle, waiting room, host video, and test room generation)
    5. Review & Launch Sanctuary: Summary card and launch button that persists completion and redirects to the Profiler.

### 4. Automated Zoom Meeting Generation for Class Batches
- When `zoomConnected && zoomAutoMeetingEnabled`:
  - Creating a batch automatically provisions a Zoom room (`https://us05web.zoom.us/j/{meeting_id}?pwd={passcode}`).
  - Batch cards render a blue "Zoom Live" badge and a direct "Launch Zoom" action link.
  - The "Create New Class Batch" modal displays the connected Zoom account indicator, waiting room security note, and preview button.

### 5. Studio Profiler & Settings View
- Located under the **Settings & Profiler** tab (`activeTab === "settings"`):
  - **Header**: Displays Sanctuary verification status badge, "Edit in Setup Wizard" button, and link to public website.
  - **Card 1**: Studio Identity & Primary Mobile Phone (with WhatsApp confirmation badge, disciplines pills, email, tagline).
  - **Card 2**: Studio Location & Teaching Mode (Mode badge: In-Studio / Online / Hybrid, full street address, city, state, PIN).
  - **Card 3**: Legal Business & GST Details (Legal business name, GST status, 15-digit GSTIN, PAN, tax invoice compliance note).
  - **Card 4**: Bank Payouts & Settlement Account ("The Thanks Perspective": Bank name, beneficiary, masked account number with shield icon, IFSC, UPI ID, weekly cycle).
  - **Card 5**: Zoom Live Classroom Integration (Connected account email, automation status, security settings, generate test room button, disconnect button).

---

## Verification & Testing Guide

### Automated Tests
```bash
cd progressrooms-api
.venv/bin/pytest tests/test_studio_profile_and_zoom.py tests/test_auth.py
.venv/bin/pytest tests/
```
All 8 backend test suites pass with 100% success.

### Frontend Compilation
```bash
cd progressrooms-web
npm run build
```
Production build compiles with 0 TypeScript/ESLint errors.

### Manual Verification Steps
1. Navigate to `/register` and create a new studio account (e.g. `Rohan Yoga Shala`).
2. Verify OTP code `123456`.
3. Confirm landing page directs immediately to the **Account Completion** tab with "Setup Req." badge.
4. Click "🌿 Fill Sample Sanctuary Details" or enter custom details for phone, location, GST, and bank account.
5. In Step 4, click "Connect Zoom Account" and verify test meeting generation.
6. In Step 5, click "🚀 Complete Setup & Launch Sanctuary".
7. Verify automatic redirect to **Studio Profiler & Settings** with all 5 cards showing saved information (phone, GST, location, masked bank account, Zoom).
8. Switch to **Class Batches & Schedules** -> Click "Create New Class Batch".
9. Notice the Zoom integration badge; submit the form.
10. Verify that the new batch appears with the "Zoom Live" badge and direct "Launch Zoom" link.
