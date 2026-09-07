# FEAT-05: Class Batches & Scheduling Engine

- **Feature ID**: FEAT-05
- **Status**: ✅ COMPLETED & VERIFIED
- **Date**: 2026-09-07
- **Module**: `progressrooms-web` (Dashboard & Modal) + `progressrooms-api` (Scheduling Engine & Occurrence Generator)

---

## 1. Overview
Allows studio owners and administrators to configure weekly recurring class batches (e.g. *Morning Hatha Flow*, *Aerial Yoga Conditioning*, *Sunset Vinyasa*). It features **real-time double-booking conflict detection** to prevent assigning an instructor to overlapping slots, and immediately provisions the class into the timetable and daily attendance rosters.

## 2. Key Capabilities Implemented
1. **Interactive Batch Creation Modal**:
   - Accessible via the **"Create Class Batch"** button in the *Class Batches & Schedules* tab.
   - Inputs for:
     - Batch / Session Name
     - Class Type (Hatha, Aerial Yoga, Vinyasa, Meditation, Pilates, Workshop)
     - Assigned Instructor (e.g., Sahil Sharma, Ananya Sen)
     - Weekly Recurrence Days (multi-select day pills: Mon, Tue, Wed, Thu, Fri, Sat, Sun)
     - Start Time & End Time
     - Max Yogi Capacity
     - Monthly Subscription Fee (₹)
     - Automated Video Meeting Link (Zoom, Meet)
2. **Double-Booking Conflict Engine**:
   - In real time, as the administrator changes instructor, days, or hours, the engine checks for schedule conflicts against all existing active batches.
   - If an overlap exists, an alert banner warns:
     `⚠️ Scheduling Warning: Instructor [Name] already teaches "[Conflicting Batch]" on [Days] between [Start] and [End].`
3. **Reactive Persistence & Roster Sync**:
   - Newly created batches appear instantly in the Batches list.
   - They are dynamically added to the **Attendance Tracker** dropdown.
   - Persisted in local browser storage (`pr_studio_batches`) so created classes persist across reloads.
   - Backend endpoint `POST /api/v1/organizations/{org_id}/sessions` triggers 30-day occurrence generation.

## 3. Files Implemented & Modified
- `progressrooms-web/src/app/(dashboard)/dashboard/page.tsx`
- `progressrooms-api/app/modules/classes/router.py`
- `progressrooms-api/app/modules/scheduling/engine.py`

## 4. Verification & Testing Steps
1. Navigate to `http://localhost:3000/dashboard` and click the **"✨ Class Batches & Schedules"** tab.
2. Click the green button **"Create Class Batch"**:
   - Notice the backdrop modal appearing with nature styling (`#0C2417`, `#CEDECF`).
3. **Test Conflict Detection**:
   - Select instructor **Ananya Sen (Aerial Specialist)**.
   - Set the day to **Tue** and time to **18:00** - **19:00**.
   - Notice the immediate amber warning banner:
     `⚠️ Scheduling Warning: Instructor Ananya already teaches "Aerial Yoga Conditioning" on Tue/Thu between 18:00 and 19:00.`
4. **Create a Non-Conflicting Batch**:
   - Change Batch Name to `"Sunset Vinyasa Flow"`.
   - Set Class Type to `"Vinyasa Flow"`.
   - Instructor: `"Sahil Sharma (Lead Guru)"`.
   - Days: select `"Mon"`, `"Wed"`, `"Fri"`.
   - Start Time: `17:30`, End Time: `18:30`.
   - Price: `2,800`.
   - Click **"🌿 Create Batch & Generate Timetable"**.
5. **Verify New Batch**:
   - The modal closes and a toast notification displays: `"🌿 New Batch 'Sunset Vinyasa Flow' created! 30-day timetable generated."`.
   - The new card appears in the Batches grid with full details.
   - Switch to the **"🗓️ Attendance Tracker"** tab and open the class dropdown: confirm `"Sunset Vinyasa Flow"` is selectable!
