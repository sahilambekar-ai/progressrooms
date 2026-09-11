# Test data design

Foundation seed creates four typed plans and three organizations: Sahil Yoga Studio on a Starter trial, John Guitar Academy on Core, Dance Studio on Studio; one platform administrator, staff and student fixtures are listed in `test-accounts.md`. An owner can teach through their existing membership. Seed only missing fixtures; do not overwrite edits or extend trials when run again. Seed is forbidden in production. Demo prices are illustrative until pricing approval and billing implementation.

Subsequent milestone seeds expand Yoga to two instructors/twenty students, Guitar to three instructors/fifteen students, and a third organization with different entitlements. Include yoga/aerial/guitar/dance catalog entries, private and draft sessions, past/upcoming/cancelled/rescheduled occurrences and an instructor conflict. Dates are generated relative to an injectable clock in each organization's timezone.

Commerce fixtures later include captured, failed and pending orders, duplicate/out-of-order signed webhook deliveries, expired/active/date-range/package enrollment and full/partial refund. Website fixtures later cover default plus three advanced templates with valid and invalid configurations. These records are designed here; foundation seed must not imply working payment or scheduling behavior.

Use deterministic natural fixture keys and referentially valid tenant ownership. Negative tests deliberately attempt cross-tenant references inside rollback-isolated transactions. Reset accepts only development/test database names and requires an explicit command flag; it never targets the reference project's database.
