# ProgressRooms PostgreSQL Database Schema Specification

All database primary keys are UUIDv4. All timestamps use `TIMESTAMPTZ`.

## 1. Authentication & Platform
- `users`: `id (UUID PK)`, `email (VARCHAR UNIQUE)`, `phone (VARCHAR)`, `full_name (VARCHAR)`, `avatar_url (VARCHAR)`, `is_active (BOOLEAN)`, `created_at`, `updated_at`, `deleted_at`.
- `user_auth_methods`: `id (UUID PK)`, `user_id (UUID FK users)`, `auth_type (VARCHAR: OTP, PASSWORD, GOOGLE)`, `credential_hash (VARCHAR)`, `created_at`.
- `user_sessions`: `id (UUID PK)`, `user_id (UUID FK users)`, `token (VARCHAR UNIQUE)`, `ip_address (VARCHAR)`, `user_agent (VARCHAR)`, `expires_at`, `created_at`.
- `platform_admins`: `id (UUID PK)`, `user_id (UUID FK users UNIQUE)`, `role (VARCHAR: SUPER_ADMIN)`, `created_at`.

## 2. Multi-Tenant Organizations
- `organizations`: `id (UUID PK)`, `name (VARCHAR)`, `slug (VARCHAR UNIQUE)`, `logo_url (VARCHAR)`, `timezone (VARCHAR: DEFAULT 'UTC')`, `currency (VARCHAR: DEFAULT 'INR')`, `status (VARCHAR: ACTIVE, SUSPENDED)`, `created_at`, `updated_at`, `deleted_at`.
- `organization_members`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `user_id (UUID FK users)`, `role (VARCHAR: OWNER, ADMIN, INSTRUCTOR)`, `bio (TEXT)`, `title (VARCHAR)`, `is_active (BOOLEAN)`, `created_at`, `updated_at`.
- `organization_students`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `user_id (UUID FK users)`, `student_notes (TEXT)`, `status (VARCHAR: ACTIVE, INACTIVE)`, `created_at`.
- `organization_settings`: `id (UUID PK)`, `organization_id (UUID FK organizations UNIQUE)`, `brand_color (VARCHAR)`, `support_email (VARCHAR)`, `support_phone (VARCHAR)`, `zoom_connected (BOOLEAN)`, `created_at`, `updated_at`.

## 3. Plans & Entitlements
- `plans`: `id (UUID PK)`, `name (VARCHAR)`, `slug (VARCHAR UNIQUE)`, `description (TEXT)`, `price (NUMERIC(10,2))`, `currency (VARCHAR)`, `billing_interval (VARCHAR: MONTHLY, YEARLY)`, `status (VARCHAR: ACTIVE, ARCHIVED)`, `is_public (BOOLEAN)`, `created_at`, `updated_at`.
- `plan_features`: `id (UUID PK)`, `plan_id (UUID FK plans)`, `feature_key (VARCHAR)`, `feature_value (VARCHAR)`, `created_at`, `updated_at`.
- `organization_subscriptions`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `plan_id (UUID FK plans)`, `status (VARCHAR: TRIAL, ACTIVE, PAST_DUE, EXPIRED, CANCELLED)`, `starts_at (TIMESTAMPTZ)`, `ends_at (TIMESTAMPTZ)`, `trial_starts_at`, `trial_ends_at`, `payment_provider (VARCHAR)`, `provider_subscription_id (VARCHAR)`, `created_at`, `updated_at`.

## 4. Classes & Sessions
- `class_types`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `name (VARCHAR)`, `slug (VARCHAR)`, `description (TEXT)`, `created_at`, `updated_at`, `deleted_at`.
- `sessions`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `class_type_id (UUID FK class_types)`, `name (VARCHAR)`, `slug (VARCHAR)`, `short_description (VARCHAR)`, `full_description (TEXT)`, `session_type (VARCHAR: GROUP, ONE_TO_ONE, WORKSHOP, PROGRAM)`, `capacity (INT)`, `min_age (INT)`, `max_age (INT)`, `skill_level (VARCHAR: ALL_LEVELS, BEGINNER, INTERMEDIATE, ADVANCED)`, `duration_minutes (INT)`, `language (VARCHAR)`, `is_active (BOOLEAN)`, `is_public (BOOLEAN)`, `meeting_url (VARCHAR)`, `created_at`, `updated_at`, `deleted_at`.
- `session_instructors`: `id (UUID PK)`, `session_id (UUID FK sessions)`, `member_id (UUID FK organization_members)`, `role (VARCHAR: PRIMARY, SECONDARY, SUBSTITUTE)`, `created_at`.
- `session_pricing`: `id (UUID PK)`, `session_id (UUID FK sessions UNIQUE)`, `pricing_type (VARCHAR: ONE_TIME, MONTHLY, PACKAGE, PER_SESSION)`, `price (NUMERIC(10,2))`, `currency (VARCHAR)`, `total_classes (INT)`, `validity_days (INT)`, `created_at`, `updated_at`.
- `session_requirements`: `id (UUID PK)`, `session_id (UUID FK sessions UNIQUE)`, `prerequisites (TEXT)`, `required_equipment (TEXT)`, `preparation_instructions (TEXT)`, `additional_notes (TEXT)`, `created_at`, `updated_at`.

## 5. Scheduling & Occurrences
- `session_schedule_rules`: `id (UUID PK)`, `session_id (UUID FK sessions)`, `day_of_week (INT: 0-6)`, `start_time (TIME)`, `end_time (TIME)`, `timezone (VARCHAR)`, `effective_start_date (DATE)`, `effective_end_date (DATE)`, `is_active (BOOLEAN)`, `created_at`, `updated_at`.
- `class_occurrences`: `id (UUID PK)`, `session_id (UUID FK sessions)`, `organization_id (UUID FK organizations)`, `instructor_id (UUID FK organization_members)`, `scheduled_start_at (TIMESTAMPTZ)`, `scheduled_end_at (TIMESTAMPTZ)`, `actual_start_at (TIMESTAMPTZ)`, `actual_end_at (TIMESTAMPTZ)`, `status (VARCHAR: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED, RESCHEDULED)`, `meeting_url (VARCHAR)`, `cancellation_reason (TEXT)`, `created_at`, `updated_at`.
- `class_occurrence_changes`: `id (UUID PK)`, `class_occurrence_id (UUID FK class_occurrences)`, `changed_by_user_id (UUID FK users)`, `change_type (VARCHAR: RESCHEDULE, CANCEL, INSTRUCTOR_CHANGE)`, `previous_start_at (TIMESTAMPTZ)`, `new_start_at (TIMESTAMPTZ)`, `reason (TEXT)`, `created_at`.

## 6. Commerce & Enrollments
- `orders`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `user_id (UUID FK users)`, `order_number (VARCHAR UNIQUE)`, `total_amount (NUMERIC(10,2))`, `currency (VARCHAR)`, `status (VARCHAR: PENDING, PAID, FAILED, REFUNDED)`, `created_at`, `updated_at`.
- `order_items`: `id (UUID PK)`, `order_id (UUID FK orders)`, `session_id (UUID FK sessions)`, `unit_price (NUMERIC(10,2))`, `quantity (INT)`, `subtotal (NUMERIC(10,2))`, `created_at`.
- `payments`: `id (UUID PK)`, `order_id (UUID FK orders)`, `amount (NUMERIC(10,2))`, `currency (VARCHAR)`, `payment_provider (VARCHAR: RAZORPAY)`, `provider_order_id (VARCHAR)`, `provider_payment_id (VARCHAR)`, `provider_signature (VARCHAR)`, `status (VARCHAR: PENDING, SUCCESS, FAILED, REFUNDED)`, `idempotency_key (VARCHAR UNIQUE)`, `created_at`, `updated_at`.
- `payment_webhook_events`: `id (UUID PK)`, `event_id (VARCHAR UNIQUE)`, `event_type (VARCHAR)`, `payload (JSONB)`, `is_processed (BOOLEAN)`, `processed_at (TIMESTAMPTZ)`, `created_at`.
- `organization_payment_accounts`: `id (UUID PK)`, `organization_id (UUID FK organizations UNIQUE)`, `provider (VARCHAR: RAZORPAY)`, `key_id (VARCHAR)`, `key_secret_enc (VARCHAR)`, `is_active (BOOLEAN)`, `created_at`, `updated_at`.
- `session_enrollments`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `session_id (UUID FK sessions)`, `user_id (UUID FK users)`, `order_id (UUID FK orders)`, `status (VARCHAR: ACTIVE, EXPIRED, CANCELLED)`, `valid_from (TIMESTAMPTZ)`, `valid_until (TIMESTAMPTZ)`, `total_sessions (INT)`, `sessions_attended (INT: DEFAULT 0)`, `created_at`, `updated_at`.
- `attendance_records`: `id (UUID PK)`, `class_occurrence_id (UUID FK class_occurrences)`, `session_enrollment_id (UUID FK session_enrollments)`, `status (VARCHAR: ATTENDED, ABSENT, EXCUSED)`, `marked_by_user_id (UUID FK users)`, `marked_at (TIMESTAMPTZ)`, `notes (TEXT)`, `created_at`.

## 7. Website System
- `website_templates`: `id (UUID PK)`, `name (VARCHAR)`, `code (VARCHAR UNIQUE: DEFAULT, TEMPLATE_A, TEMPLATE_B, TEMPLATE_C)`, `preview_image_url (VARCHAR)`, `is_active (BOOLEAN)`, `created_at`.
- `organization_websites`: `id (UUID PK)`, `organization_id (UUID FK organizations UNIQUE)`, `template_id (UUID FK website_templates)`, `headline (VARCHAR)`, `subheadline (VARCHAR)`, `hero_image_url (VARCHAR)`, `about_text (TEXT)`, `primary_color (VARCHAR)`, `accent_color (VARCHAR)`, `social_links (JSONB)`, `custom_sections (JSONB)`, `is_published (BOOLEAN)`, `created_at`, `updated_at`.
- `organization_domains`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `domain_name (VARCHAR UNIQUE)`, `is_verified (BOOLEAN)`, `ssl_status (VARCHAR)`, `created_at`.
- `media_assets`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `file_name (VARCHAR)`, `file_url (VARCHAR)`, `mime_type (VARCHAR)`, `size_bytes (BIGINT)`, `created_at`, `deleted_at`.

## 8. Integrations, Notifications & Audit
- `organization_integrations`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `provider (VARCHAR: ZOOM)`, `credentials_enc (TEXT)`, `is_active (BOOLEAN)`, `created_at`, `updated_at`.
- `notifications`: `id (UUID PK)`, `user_id (UUID FK users)`, `organization_id (UUID FK organizations)`, `title (VARCHAR)`, `message (TEXT)`, `type (VARCHAR: CLASS_REMINDER, PAYMENT, ANNOUNCEMENT)`, `is_read (BOOLEAN)`, `created_at`.
- `audit_logs`: `id (UUID PK)`, `organization_id (UUID FK organizations)`, `user_id (UUID FK users)`, `entity_type (VARCHAR)`, `entity_id (UUID)`, `action (VARCHAR)`, `old_data (JSONB)`, `new_data (JSONB)`, `ip_address (VARCHAR)`, `created_at`.
