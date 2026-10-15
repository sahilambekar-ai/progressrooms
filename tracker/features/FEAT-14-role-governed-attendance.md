# FEAT-14: Role-governed attendance and student session queries

- **Status**: 🟡 SPECIFIED — requires API/web implementation in the application repository.
- **Database migration**: `006_attendance_permissions_and_student_session_queries`

## Rules

1. A studio owner can create and correct attendance for both teachers and students in that studio.
2. A teacher can create and correct attendance only for an assigned student in an assigned class. Teachers cannot edit teacher attendance, including their own.
3. Students cannot edit attendance. They can submit a postpone request for a specific upcoming class occurrence or an extension request for their own active session enrollment through Student Queries.
4. A query goes only to the student's assigned teacher. That teacher can approve or reject it; approval never silently reschedules a class or extends paid access.

## Persistence

`teacher_attendance_records` stores one teacher status per occurrence and teacher. `student_session_queries` stores request type, current status, message, optional teacher response, resolution metadata, and the teacher recipient frozen at creation. The composite foreign key guarantees that recipient is the student’s assigned teacher at creation.

## API acceptance tests

1. Studio owner marks and corrects a teacher and a student attendance record within the studio.
2. A teacher marks attendance for a student assigned to the teacher and their class.
3. The same teacher receives `403` when attempting teacher attendance, including their own, and student attendance outside their assignment.
4. A student receives `403` on either attendance write endpoint.
5. A student creates a `POSTPONE` query only for their own future occurrence and an `EXTEND` query only for their own active enrollment.
6. Only the recipient teacher can list and resolve the query; the student can withdraw it only while `PENDING`.
7. Reassignment after query creation does not expose that query to the new teacher. A deactivated teacher cannot resolve it.
