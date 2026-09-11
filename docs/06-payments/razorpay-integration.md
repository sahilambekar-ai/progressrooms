# Razorpay integration

Status: provider design; implement and test in the commerce milestone before enabling live payments. Provider documentation reviewed 2026-09-09. Revalidate integration details at implementation and go-live.

## Adapter boundary and configuration

The Razorpay adapter supports create/fetch order, verify checkout result, verify webhook, fetch payment, request/fetch refund and later Route settlement operations. Domain services consume normalized results. Test and live keys, webhook secrets and provider-account identifiers must be isolated by environment. The key ID is checkout-safe; key secret and webhook secret are server-only and are distinct credentials.

Store organization account metadata in `organization_payment_accounts`. Credential material lives in the environment secret store or encrypted integration storage with key rotation. Provider account IDs are included in reconciliation/deduplication scope where identifiers could overlap across configurations. Never infer the organization solely from a browser field or untrusted provider notes.

## Webhook protocol

Verify `X-Razorpay-Signature` as HMAC-SHA256 over the exact raw request body using the configured webhook secret, with a constant-time comparison. Parse JSON only after verification. Use `x-razorpay-event-id` to deduplicate durable ingress. Expect duplicate and out-of-order delivery. Retain the prior secret during rotation for old retried requests. These mechanics follow [Razorpay's webhook validation documentation](https://razorpay.com/docs/webhooks/validate-test/).

The endpoint has a bounded request size, controlled content type, timeout budget and no user-cookie dependency. Return success after durable insertion; do not wait for enrollment work. If persistence fails, return a retryable error. A verified duplicate is acknowledged. A valid but unsupported event can be stored as ignored. Business-state mismatches are quarantined for reconciliation instead of repeatedly crashing ingress.

Initially process captured payment/order-paid confirmation through one verified fulfillment service; confirm the payload's current payment state before granting access. An authorization event alone is insufficient. Verify internal/provider order linkage, account, expected amount and currency. Checkout signature verification may speed up status reconciliation but does not remove the webhook/reconciliation path.

## Teacher settlement

Razorpay Route provides linked accounts and transfers for payments split among third parties. Eligibility and onboarding requirements apply; integration design must be validated for ProgressRooms' actual business/account setup. The architecture reserves organization account, transfer/reversal and settlement references, and keeps settlement distinct from enrollment fulfillment. This design derives from [Razorpay Route](https://razorpay.com/docs/payments/route/) and [linked account documentation](https://razorpay.com/docs/payments/route/linked-account/).

Do not enable live class collection until the merchant-of-record, connected/linked account model, fees, refunds, dispute handling and settlement ownership are confirmed with the payment provider. A sandbox implementation may simulate these records with clearly marked mock identifiers. Do not describe basic checkout as a completed marketplace settlement integration.

## Test and launch checklist

Use test-mode orders with unique internal receipts, signed test webhooks and provider test payments. Exercise callback absence, signature mutation, duplicate event ID, captured-before-authorized event order, mismatched amount/currency, refund retry and delayed confirmation. Mock deterministic failures in CI; use a staging public HTTPS endpoint for provider delivery tests. Store only sanitized fixtures.

Go-live requires a configured HTTPS webhook, separate live secret, account mapping, validated captured-payment fulfillment, documented reconciliation and refund ownership, observable event lag, and an operator replay procedure. Provider secrets must never enter source control, frontend bundles, analytics or API responses.
