# FEAT-06: Daily Attendance Tracker & Real-Time Roster Sync

- **Feature ID**: FEAT-06
- **Status**: ✅ COMPLETED & VERIFIED
- **Date**: 2026-09-07
- **Module**: `progressrooms-web` (Attendance View) + `progressrooms-api` (Attendance Router)

---

## 1. Overview
The Attendance Tracker tab (`/dashboard -> Attendance Tracker`) enables studio instructors to select any class batch and date, take daily attendance, toggle individual student status with instant visual feedback, and batch mark attendance.

## 2. Key Capabilities Implemented
1. **Date & Batch Filters**:
   - Date picker allowing instructors to view and log attendance for any day (past, today, future).
   - Dynamic class batch selector automatically populated with both default and custom created batches.
2. **One-Click Batch Actions**:
   - **"Mark All Present"**: Instantly marks all students in the roster as `ATTENDED` and increments their attended class counters.
   - **"Clear Roster"**: Resets students to `ABSENT`.
3. **Individual Toggle & Counter Sync**:
   - Clicking the round status icon or "Change Status" immediately toggles between `ATTENDED` (emerald badge) and `ABSENT` (red badge).
   - Real-time reactivity: The student's attended count (e.g. `8 / 12 Sessions Logged`) updates immediately in both the Attendance Tracker and the **Students & Directory** roster.
4. **Persistent State Storage**:
   - Attendance status and student counts are stored in browser storage (`pr_attendance_records` & `pr_students_list`), preserving instructor changes across page reloads.

## 3. Files Implemented & Modified
- `progressrooms-web/src/app/(dashboard)/dashboard/page.tsx`
- `progressrooms-api/app/modules/attendance/router.py`

## 4. Verification & Testing Steps
1. Navigate to `http://localhost:3000/dashboard` and click the **"🗓️ Attendance Tracker"** tab.
2. Observe the session info banner displaying the class name, instructor, time, and selected date.
3. **Test Individual Attendance Toggle**:
   - Find student **Rohan Verma** (currently marked `ABSENT`).
   - Click the status toggle button next to his name.
   - Observe that his status badge switches to `ATTENDED` (emerald) and a confirmation toast appears: `"Attendance updated: ATTENDED"`.
4. **Test Roster Cross-Tab Sync**:
   - Switch to the **"👥 Students & Directory"** tab.
   - Verify that Rohan Verma's attended counter incremented from 11 to 12 sessions.
5. **Test "Mark All Present"**:
   - Return to the Attendance Tracker.
   - Click the green button **"Mark All Present"**.
   - Verify all students display the green `ATTENDED` badge and a toast confirms: `"All students marked as ATTENDED"`.

## 5. Person Attendance Views

The main Attendance Tracker now opens on **Teacher attendance** and also provides a **Student attendance** tab. Each tab has an independent person selector whose results load 300 ms after typing. Selecting a person limits both the Month calendar and Day view to that person. The existing batch checklist remains available as a secondary expandable tool.

Teacher and student management tables open a read-only details pop-up when a row is selected. Their table action and pop-up action both open Attendance Tracker with the correct tab and person preselected in Month view.

Verification completed on 2026-09-25:

- TypeScript validation and whitespace checks pass.
- Browser check confirmed Teacher is the default tab, Student search results, person-filtered Month view, Day mode, the student details pop-up, and preselected Month navigation from its View attendance action.
