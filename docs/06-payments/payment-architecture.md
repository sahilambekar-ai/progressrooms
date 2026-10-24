# Payment architecture

Status: design for student commerce; no live checkout or enrollment fulfillment is claimed by the foundation.

Progress Rooms subscription billing and student class purchases are separate domains. Student money belongs to the teaching organization. Order creation must identify the intended organization payment account; platform collection must not become an unexamined permanent settlement assumption.

## Order and pricing

Accept a pricing-option ID and buyer identity, then load an active, entitled, public offering in the target tenant. The server calculates integer minor-unit subtotal, discount, tax and total; currency and all amount relationships are validated. Snapshot session name, selected price, access policy and terms into an order item. Initial quantity is one for session access. The order references `organization_student_id`, created idempotently from the global user.

Use an idempotency key scoped to buyer + operation with a request fingerprint. Reusing a key with identical input returns the original result; changed input returns 409. Capacity and purchase limits are checked transactionally. Reserve a seat through an explicit expiring reservation before launching checkout if enrollment capacity is sold. Captured payments arriving after reservation expiry must enter a defined fulfill-or-refund recovery path, never silently oversell.

## Payment initiation and attempts

Create the internal order first; then create the provider order outside a long database lock using the internal order ID as a reconciliation reference. Persist the provider order association before giving checkout details to the browser. On ambiguous provider timeout, query/reconcile before retrying order creation. Each attempt records sanitized status and failure code without replacing the immutable order snapshot.

The browser receives only provider public key ID, provider order ID, amount, currency and display information. Browser success indicates a result to verify; it never marks the internal order paid. Show Confirming payment and poll the student's own order until fulfillment, failure or a reasonable support state.

## Authoritative confirmation

Webhook ingress verifies the signature over raw bytes, durably stores a deduplicated event and acknowledges. A worker validates provider account, order identity, captured status, amount and currency. Invalid/mismatched events are quarantined with a safe error code. Both webhook and reconciliation feed the same state-transition service.

Under one transaction, lock the order, deduplicate the provider payment, update payment and order state, create exactly one access grant per paid order item, append audit history and create notification/outbox records. A unique fulfillment key is mandatory. Repeated captured events are harmless; late failed/authorized events cannot regress a captured payment.

## Enrollment access and renewal

Supported access policies are DATE_RANGE, NUMBER_OF_CLASSES, PROGRAM_DURATION and UNLIMITED. Store purchased terms, starts/ends and class credits. Time intervals are half-open. A class-count purchase does not imply recurring billing. Attendance consumes a class only once under a row lock, with an explicit reversal on correction.

Renewal creates a new order and preserves its lineage to the existing enrollment. A duration extension begins at `max(current_end, paid_at)` unless the published product specifies another start policy. Serialize concurrent renewals to prevent lost extensions. Prefer immutable grant/period history over changing the original purchased terms. Notifications arise from committed access changes and can be retried independently.

## Refunds and reconciliation

An authorized owner or platform finance administrator requests a refund with amount, reason and idempotency key. Lock the payment and reserve the refundable amount so concurrent refunds cannot exceed captured funds. The provider call occurs outside the transaction. Pending refunds do not become final merely from request acceptance; verified provider state updates the record. Partial refunds, transfer reversals and enrollment access changes follow an explicit policy.

Initially do not infer “half the money = half the classes”. Before a production refund feature, define unused-access calculation, consumed attendance treatment, taxes and customer communication. Record financial history instead of deleting payment rows. Failed refunds remain visible and retryable with the original operation identifier.

A reconciliation job checks stale pending orders/attempts, unprocessed events, provider-confirmed captures without fulfillment and refunds awaiting confirmation. Alert on mismatches and fulfillment lag. Replay uses the same idempotent transition functions. Financial logs contain internal IDs and sanitized codes, not complete provider payloads or card details.

## Acceptance gates

Test successful capture, checkout abandonment, failed attempt then successful retry, duplicate/out-of-order webhooks, invalid signature, wrong account/order/amount/currency, concurrent order submission, concurrent fulfillment, capacity exhaustion, worker crash before/after commit, duplicate attendance, refund overrun and reconciliation recovery. A complete payment test proves exactly one paid order item and exactly one access grant.
