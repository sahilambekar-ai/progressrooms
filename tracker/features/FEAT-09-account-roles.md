# FEAT-09: Account roles and teacher portal

Database-first implementation: [role architecture](../../docs/03-database/account-roles.md).

## Implementation

- API migrations `004_account_roles`, `005_auth_schema_parity`; User / OrganizationMember / OrganizationStudent models.
- Auth, teacher, student, class, scheduling, attendance, organization and website permissions.
- Web `/teacher`, separate studio/student registration entry points, authenticated dashboard guard, `StudioClasses`, `StudentTeacherAssignments`.
- Tests: `tests/test_account_roles.py`; existing auth tests updated for explicit registration.

## Manual verification

1. Register and verify a studio through `/register/studio`; confirm users.role=STUDIO and membership.role=STUDIO.
2. As its owner, add a teacher with all profile and credential fields. Log out and sign in with that email/password. Confirm Classes opens first and Profile is fourth, with no website/settings/class-creation controls.
3. As owner, create a class assigned to that teacher, scheduled today in the studio timezone. Verify the teacher sees it and can create a persistent join link; refresh and verify Join is displayed.
4. Register a student at `/register/student` using name/email/password/phone/location; verify their account. In the studio student directory, add that registered student to the teacher's class. No payment is recorded by this manual admission.
5. As teacher, see the assigned student, edit notes, select the class under Student Attendance, and mark present. Repeat the same marking and verify the count is unchanged.
6. Verify another studio cannot manage the teacher or assign its teacher to this student's record. Verify teachers receive 403 on studio profile/website access and class creation/reschedule/cancel.
7. Deactivate a teacher; verify their existing login token cannot access the portal. Confirm historical class and attendance records remain.
8. For a teacher without today's classes, create a class tomorrow and verify tomorrow's agenda. For no classes on either day, verify the empty state.
9. Super-admin identity remains the pre-existing singleton account until the user's email is specified.

Validation result: 44 API tests passed; production build passed; clean PostgreSQL migration from revision 001 through 005 passed in an isolated temporary schema, including rejection of a second super admin. The student registration page was also inspected in the browser.
