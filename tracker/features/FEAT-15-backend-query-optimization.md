# FEAT-15 — Backend query optimization

Implemented 2026-09-29. See [full review](../../docs/02-architecture/backend-optimization-review.md) for findings, table decisions and deployment limits.

Files: scheduling/engine.py; attendance/router.py; student/router.py; classes/service.py; organizations/router.py; websites/router.py; auth/service.py; models/schedule.py and commerce.py; Alembic 008; tests/test_optimization.py and test_query_improvements.py.

Changes: batch schedule duplicate reads, refresh pending schedule replacements, limited conflict lookup, joined attendance roster, enrollment subquery, smaller completion scans, remove unused eager loads and redundant plaintext OTP storage, add three query indexes.

Verification:

1. Run `.venv/bin/python -m pytest -q` from progressrooms-api.
2. Generate revision 008 SQL with `.venv/bin/alembic upgrade 007_student_profiles_pause:008_query_indexes --sql` and inspect the three indexes.
3. In an isolated development database, generate a recurring class twice: the second generation must add no occurrences. Replace its rules and verify newly generated times.
4. Mark attendance on one occurrence; another occurrence must show UNMARKED while history remains unchanged.
5. Request and verify an OTP with email mocked/disabled; user_otps stores its hash and no new OTP mirror appears in user_auth_methods.
6. Compare student upcoming classes before/after; multiple enrollments for one class must not duplicate occurrences.

Validation result: 61 tests passed; PostgreSQL revision 008 SQL generation succeeded.

No live migration or table removal performed. PostgreSQL concurrency and query-plan validation remain deployment checks.
