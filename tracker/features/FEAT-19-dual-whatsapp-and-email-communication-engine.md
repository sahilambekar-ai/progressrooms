# FEAT-19 — Dual WhatsApp & Brevo Email Communication Engine

## Overview

Centralized, outbound operational notification infrastructure for Progress Rooms:
1. **Progress Rooms Admin WhatsApp Sender**: Subscription invoices, upcoming due dates, overdue notices, payment confirmations, account/service alerts.
2. **Progress Rooms Classes WhatsApp Sender**: Two scheduled class reminders (2-hour preparation message and 15-minute starting soon notice), material schedule corrections, cancellations.
3. **Brevo Transactional Email**: Corresponding operational emails for class schedules and billing events, alongside independent authentication emails (login OTPs and password resets).
4. **Platform-Wide Backend Switches**: Super Admin controls placed beside the existing developer-mode toggle, enabling/suppressing operational sends across all studios while strictly preserving authentication email delivery.

## Behavior

- **Platform-wide scope**: All WhatsApp senders are owned and funded by Progress Rooms. Scope clearly marked "Applies to all studios".
- **Backend-enforced toggles**: Stored in `platform_communication_settings` and enforced by API endpoints and dispatch jobs.
- **Toggle audit trail**: Every switch change records `previous_state`, `new_state`, `changed_by_email`, timestamp, and notes in `communication_channel_audit_logs`.
- **Suppression logging**: Disabling a channel suppresses operational dispatches and records activity in `communication_logs` with explicit reasons (e.g., `"Suppressed: email disabled"`, `"Suppressed: whatsapp disabled"`).
- **Authentication immunity**: User login OTPs, verification passcodes, and password resets are separately controlled and bypass the operational toggle, ensuring users are never locked out of their accounts.
- **Double-off warning**: When both WhatsApp and Email operational channels are disabled, high-visibility warning banners appear across the platform dashboard and controls.
- **Test dispatch**: Super Admin can dispatch clearly labelled tests verifying routing and receiving real-time status output.

## Files

- **API Models**: [`progressrooms-api/app/models/communication.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/models/communication.py), [`progressrooms-api/app/models/__init__.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/models/__init__.py).
- **API Services & Routers**:
  - [`progressrooms-api/app/modules/communication/schemas.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/modules/communication/schemas.py)
  - [`progressrooms-api/app/modules/communication/service.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/modules/communication/service.py)
  - [`progressrooms-api/app/modules/communication/templates.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/modules/communication/templates.py)
  - [`progressrooms-api/app/modules/communication/reminder_engine.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/modules/communication/reminder_engine.py)
  - [`progressrooms-api/app/modules/communication/billing_engine.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/modules/communication/billing_engine.py)
  - [`progressrooms-api/app/modules/communication/router.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/modules/communication/router.py)
  - [`progressrooms-api/app/main.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/app/main.py)
- **Frontend Components**:
  - [`progressrooms-web/src/components/CommunicationChannelsControl.tsx`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-web/src/components/CommunicationChannelsControl.tsx) (Floating trigger beside developer mode button + interactive management modal + embeddable panel)
  - [`progressrooms-web/src/app/layout.tsx`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-web/src/app/layout.tsx) (Mounted in root layout beside developer mode)
  - [`progressrooms-web/src/app/(dashboard)/dashboard/page.tsx`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-web/src/app/(dashboard)/dashboard/page.tsx) (Embedded in Super Admin settings tab)
- **Tests**:
  - [`progressrooms-api/tests/test_communication.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/tests/test_communication.py) (RBAC, channel toggle switches, audit trail logging, suppression verification, test dispatch, auth email immunity)
  - [`progressrooms-api/tests/test_reminder_engine_acceptance.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/tests/test_reminder_engine_acceptance.py) (10 edits before T-2h produce 1 reminder; 2-min debounced material corrections; class cancellation suppresses 15m reminder; creation <2h and <15m; recipient opt-out and platform switch suppression)
  - [`progressrooms-api/tests/test_billing_and_budgets.py`](file:///Users/sahil/Documents/work/openroots/progressrooms/progressrooms-api/tests/test_billing_and_budgets.py) (Student checkout payment notices, studio subscription invoices/due-soon/overdue notices, monthly budget limits, 70%/90%/100% alerts, RESERVE_CRITICAL overage policy, and engine cycle execution)

## Verification

- **Backend Pytest**: 14 new tests passed across `test_communication.py`, `test_reminder_engine_acceptance.py`, and `test_billing_and_budgets.py`. Entire API test suite (99 tests) passes cleanly with 0 errors.
- **Frontend Build**: `npm run build` compiled successfully with 0 errors across all 14 routes.

