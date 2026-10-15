# FEAT-13 — Student profiles, pass pause/resume, membership class status

## Behavior
- Manage Students opens an editable profile for studio owners and teachers: name, required phone, optional separate WhatsApp, location, address, and studio-specific notes.
- Phone accepts 7–15 digits with international prefix/formatting; missing legacy values remain missing until supplied. Student registration and self-profile updates enforce phone server-side. New admissions require an existing phone.
- Email is the verified login identity. There is no supported email-change/reverification flow; it is explicitly read-only. Attendance, account verification, and enrollment totals are calculated/controlled by their own workflows.
- Staff can pause an individual enrolled pass. The server locks the enrollment, rejects invalid/repeated transitions, and extends expiry by elapsed pause time on manual resume. Credits are unchanged. Paused passes cannot join classes or receive attendance. No notifications are sent.
- Purchase records currently use SessionEnrollment, independently of MembershipTier catalog definitions. Controls operate on actual enrolled passes displayed by class name.
- Membership class selection refreshes when opened and includes all non-deleted classes, active or inactive, with status at the top right. No teacher-assignment fields added.

## Files
- API: common/phone.py, common/enums.py, models/user.py, models/commerce.py, modules/auth/{schemas,router,service}.py, modules/students/router.py.
- Migration: alembic/versions/007_student_profiles_pause.py (nullable columns; no invented phone values).
- Web: components/StudentDetails.tsx, components/StudioMemberships.tsx, app/(dashboard)/dashboard/page.tsx, app/register/page.tsx.
- Regression tests: tests/test_student_profiles_pause.py and updated valid phone fixtures in tests/test_account_roles.py.

## Validation
- 17 tests passed across student profile/pause, account roles, auth, classes and memberships.
- TypeScript check passed; lint passed with existing dashboard hook and website image warnings.

## Manual verification
1. Apply `alembic upgrade head` to the local API database and restart the API if it does not auto-reload.
2. Open Manage Students, click a student or Edit details, change profile fields, save, reopen and check persistence. Cancel must discard changes. Missing/invalid phone prevents saving; WhatsApp can be empty.
3. Register a student: provide phone and optionally a distinct WhatsApp number. Verify both persist.
4. With an active pass with ten days left, Pause pass. It shows PAUSED with remaining days preserved; student cannot join and attendance cannot be recorded against it. Resume later; expiry extends by the actual pause duration and used credits stay unchanged. Duplicate transitions return conflict. Other studios and student accounts cannot call these actions.
5. Open Create New Membership with both active and inactive classes; both are selectable with status badges. Save and reopen to verify attachments persist.
6. Email remains read-only pending a separate verified email-change feature.
