# ProgressRooms Payment & Commerce Architecture

## 1. Gateway & Isolation
- ProgressRooms uses **Razorpay** as the primary payment gateway for Indian and international currency processing.
- Two distinct payment domains:
  1. **Platform Subscriptions**: Teachers paying ProgressRooms for their tier (Starter/Core/Studio).
  2. **Student Commerce**: Students paying an Organization for classes.
- Organization payment accounts (`organization_payment_accounts`) store credentials or linked account references.

## 2. Order Lifecycle

```text
[Initiate Checkout]
       ↓
Create Order in DB (status: PENDING, order_number: PR-ORD-...)
       ↓
Create Order on Razorpay API (amount in paise, currency: INR)
       ↓
Frontend Razorpay Modal Opened with order_id
       ↓
Student Authorizes Payment
       ↓
Frontend submits:
- razorpay_payment_id
- razorpay_order_id
- razorpay_signature
       ↓
Backend checks HMAC-SHA256 signature with Key Secret
       ↓
Signature Valid:
- Update Payment status = SUCCESS
- Update Order status = PAID
- Create or Extend session_enrollment
```

## 3. Webhook Idempotency & Retries
- Webhooks from Razorpay arrive at `/api/v1/commerce/webhooks/razorpay`.
- Validates `X-Razorpay-Signature` with webhook secret.
- Stores event in `payment_webhook_events`. If `event_id` already exists, returns HTTP 200 immediately without reprocessing (Idempotency).
- Handles `payment.captured`, `order.paid`, `payment.failed`, and `refund.processed`.
