# Development accounts

| Identity | Role / organization |
| --- | --- |
| admin@test.progressrooms.local | Platform Super Admin |
| owner@yogastudio.test | Owner, Sahil Yoga Studio |
| ananya@yogastudio.test | Instructor, Sahil Yoga Studio |
| owner@musicstudio.test | Owner, John Guitar Academy |
| owner@movementstudio.test | Owner, Dance Studio |
| student1@test.progressrooms.local | Global student with organization student relationships |
| student2@test.progressrooms.local | Separate student for isolation checks |

Only with `APP_ENV=development` or `test` and `ALLOW_DEV_OTP=true` can allowlisted fixtures use `123456`. Request a challenge first; the code is still subject to expiry, attempts, single-use and resend budgets. No role is inferred from the email at login: roles come from seeded database records. Frontend quick login requires `ENABLE_DEMO_LOGIN=true` and a development server. Production rejects both bypass settings.

These are fixtures, not usable production email accounts. No real messages are sent for fixture login.
