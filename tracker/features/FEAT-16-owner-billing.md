# FEAT-16 — Studio owner billing

Studio owners have an owner-only **Billing Details** menu with two sections:

- **Billing Dashboard** shows subscription-value totals, current-month record count, average billing, active enrollments, and a day/week/month trend. Reports can cover all assigned teachers or one selected teacher. Billing rows use server pagination and support sorting by date, name, amount, and session count.
- **Download Bills** presents three clear modes: financial year (current FY selected by default with prior-year choices), month (current month, last 30 days, or January through December), and custom dates. Owners can download CSV or open a printable statement that can be saved as PDF. Exports include sessions taken and sessions excused/cancelled.

The report intentionally reads enrollment and class subscription values. It does not read payment, order, gateway, or transaction records. New enrollments snapshot their subscription value, currency, type, and label so later class price changes do not rewrite billing history. Existing enrollments fall back to the class's currently configured value until they are backfilled.

Backend files: `app/modules/billing/router.py`, `app/models/commerce.py`, enrollment creation services, Alembic revision 009, `app/main.py`, and `tests/test_billing.py`.

Frontend files: `src/components/BillingCenter.tsx`, `src/app/(dashboard)/dashboard/page.tsx`, and `src/app/globals.css`. Dashboard Settings also includes Midnight Pine, Obsidian, and Dark Plum themes.

Teacher and student management use backend pagination and sorting. Teachers receive a permanent unique eight-digit code, shown instead of the role in the owner's teacher table and displayed in the teacher's navigation and dashboard identity panel. The dark themes use a lighter main workspace than the sidebar and normalize table tags and fixed light colors.

Demo data: after the base seed, run `python -m scripts.seed.seed_billing_demo`. It backfills missing snapshots and idempotently creates billing values across recent days and the current financial year.

Verification:

1. Sign in as a studio owner and open Billing Details → Billing Dashboard.
2. Switch day, week, and month views and select a teacher.
3. Open Download Bills, select each preset and a custom date range, then download CSV.
4. Choose Print / Save PDF and verify the printable statement contains subscription values and no payment transaction identifiers.
5. Sign in as a teacher and verify Billing Details is absent. A direct API request must return 403.
6. Run `.venv/bin/python -m pytest -q` in `progressrooms-api` and `npm run typecheck` in `progressrooms-web`.
