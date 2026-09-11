-- ProgressRooms: PostgreSQL 16 initial full-domain schema.
-- Generated from schema-inventory.json; immutable migration is kept separately.
-- Apply through Alembic; no credentials or seed data are embedded.

CREATE TABLE users (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    full_name TEXT,
    email_verified_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_users_1 UNIQUE (email),
    CONSTRAINT ck_users_1 CHECK (email = lower(btrim(email)) AND position('@' IN email) > 1),
    CONSTRAINT ck_users_2 CHECK (status IN ('ACTIVE', 'SUSPENDED'))
);

-- statement-breakpoint

COMMENT ON TABLE users IS 'One global identity reused across all organizations; credentials and roles live separately.';

-- statement-breakpoint

CREATE TABLE user_auth_methods (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    provider TEXT NOT NULL DEFAULT 'EMAIL_OTP',
    provider_subject TEXT NOT NULL,
    password_hash TEXT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_auth_methods_1 UNIQUE (provider, provider_subject),
    CONSTRAINT uq_user_auth_methods_2 UNIQUE (user_id, provider),
    CONSTRAINT fk_user_auth_methods_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_user_auth_methods_1 CHECK ((provider = 'PASSWORD' AND password_hash IS NOT NULL) OR (provider <> 'PASSWORD' AND password_hash IS NULL)),
    CONSTRAINT ck_user_auth_methods_2 CHECK (provider IN ('EMAIL_OTP', 'PASSWORD', 'GOOGLE', 'APPLE', 'PHONE_OTP'))
);

-- statement-breakpoint

COMMENT ON TABLE user_auth_methods IS 'Future-compatible authentication method bindings; no plaintext credentials.';

-- statement-breakpoint

CREATE INDEX ix_user_auth_methods_1 ON user_auth_methods (user_id);

-- statement-breakpoint

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    ip_address INET,
    user_agent TEXT,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_sessions_1 UNIQUE (token_hash),
    CONSTRAINT fk_user_sessions_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_user_sessions_1 CHECK (expires_at > created_at)
);

-- statement-breakpoint

COMMENT ON TABLE user_sessions IS 'Revocable opaque login sessions. Store only a keyed digest of the bearer token.';

-- statement-breakpoint

CREATE INDEX ix_user_sessions_1 ON user_sessions (user_id, expires_at) WHERE revoked_at IS NULL;

-- statement-breakpoint

CREATE INDEX ix_user_sessions_2 ON user_sessions (expires_at);

-- statement-breakpoint

CREATE TABLE otp_challenges (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    purpose TEXT NOT NULL DEFAULT 'LOGIN',
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    consumed_at TIMESTAMPTZ,
    request_ip INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_otp_challenges_1 CHECK (email = lower(btrim(email))),
    CONSTRAINT ck_otp_challenges_2 CHECK (attempts >= 0 AND max_attempts BETWEEN 1 AND 10 AND attempts <= max_attempts),
    CONSTRAINT ck_otp_challenges_3 CHECK (expires_at > created_at),
    CONSTRAINT ck_otp_challenges_4 CHECK (purpose IN ('LOGIN'))
);

-- statement-breakpoint

COMMENT ON TABLE otp_challenges IS 'Short-lived, single-use OTP challenges. Keyed hashes prevent offline guessing of small code spaces.';

-- statement-breakpoint

CREATE INDEX ix_otp_challenges_1 ON otp_challenges (email, created_at DESC);

-- statement-breakpoint

CREATE INDEX ix_otp_challenges_2 ON otp_challenges (request_ip, created_at DESC);

-- statement-breakpoint

CREATE INDEX ix_otp_challenges_3 ON otp_challenges (expires_at);

-- statement-breakpoint

CREATE TABLE platform_admins (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'SUPER_ADMIN',
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_platform_admins_1 UNIQUE (user_id),
    CONSTRAINT fk_platform_admins_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_platform_admins_1 CHECK (role IN ('SUPER_ADMIN')),
    CONSTRAINT ck_platform_admins_2 CHECK (status IN ('ACTIVE', 'SUSPENDED'))
);

-- statement-breakpoint

COMMENT ON TABLE platform_admins IS 'Explicit global administrator grants; granting organization ownership never grants platform access.';

-- statement-breakpoint

CREATE TABLE organizations (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_organizations_1 UNIQUE (slug),
    CONSTRAINT ck_organizations_1 CHECK (length(btrim(name)) BETWEEN 1 AND 160),
    CONSTRAINT ck_organizations_2 CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) BETWEEN 3 AND 80),
    CONSTRAINT ck_organizations_3 CHECK (slug NOT IN ('admin', 'api', 'app', 'auth', 'login', 'logout', 'signup', 'dashboard', 'pricing', 'sessions', 'about', 'contact', 'settings', 'health', 'docs', 'openapi', 'static', 'assets', 'robots', 'sitemap', 'student', 'students', 'teacher', 'teachers', 'organizations', 'plans', 'support', 'terms', 'privacy', 'favicon', 'www', 'account', 'calendar', 'enrollments', 'payments', 'website', 'integrations')),
    CONSTRAINT ck_organizations_4 CHECK (status IN ('ACTIVE', 'SUSPENDED'))
);

-- statement-breakpoint

COMMENT ON TABLE organizations IS 'Shared business root for both individual teachers and multi-instructor studios.';

-- statement-breakpoint

CREATE TABLE organization_members (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'INSTRUCTOR',
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_members_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_members_2 UNIQUE (organization_id, user_id),
    CONSTRAINT fk_organization_members_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_members_2 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_members_1 CHECK (role IN ('OWNER', 'ADMIN', 'INSTRUCTOR')),
    CONSTRAINT ck_organization_members_2 CHECK (status IN ('ACTIVE', 'INVITED', 'SUSPENDED', 'REMOVED'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_members IS 'Staff membership only. A person may hold different roles in different tenants.';

-- statement-breakpoint

CREATE INDEX ix_organization_members_1 ON organization_members (organization_id);

-- statement-breakpoint

CREATE INDEX ix_organization_members_2 ON organization_members (user_id, status);

-- statement-breakpoint

CREATE INDEX ix_organization_members_3 ON organization_members (organization_id, role, status);

-- statement-breakpoint

CREATE TABLE organization_invitations (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'INSTRUCTOR',
    token_hash TEXT NOT NULL,
    invited_by UUID NOT NULL,
    accepted_by UUID,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_invitations_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_invitations_2 UNIQUE (token_hash),
    CONSTRAINT fk_organization_invitations_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_invitations_2 FOREIGN KEY (organization_id, invited_by) REFERENCES organization_members (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_invitations_3 FOREIGN KEY (accepted_by) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_invitations_1 CHECK (email = lower(btrim(email))),
    CONSTRAINT ck_organization_invitations_2 CHECK (expires_at > created_at),
    CONSTRAINT ck_organization_invitations_3 CHECK ((accepted_at IS NULL) = (accepted_by IS NULL)),
    CONSTRAINT ck_organization_invitations_4 CHECK (role IN ('ADMIN', 'INSTRUCTOR'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_invitations IS 'Expiring invitations grant a specific staff role only after verified-email acceptance.';

-- statement-breakpoint

CREATE INDEX ix_organization_invitations_1 ON organization_invitations (organization_id);

-- statement-breakpoint

CREATE INDEX ix_organization_invitations_2 ON organization_invitations (organization_id, email);

-- statement-breakpoint

CREATE TABLE organization_students (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    user_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_students_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_students_2 UNIQUE (organization_id, user_id),
    CONSTRAINT fk_organization_students_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_students_2 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_students_1 CHECK (status IN ('ACTIVE', 'INACTIVE', 'BLOCKED'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_students IS 'Private student relationship and notes for a tenant, backed by a global user.';

-- statement-breakpoint

CREATE INDEX ix_organization_students_1 ON organization_students (organization_id);

-- statement-breakpoint

CREATE INDEX ix_organization_students_2 ON organization_students (user_id, status);

-- statement-breakpoint

CREATE TABLE organization_settings (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    default_currency CHAR(3) NOT NULL DEFAULT 'INR',
    contact_email TEXT,
    contact_phone TEXT,
    location TEXT,
    social_links JSONB NOT NULL DEFAULT '{}'::jsonb,
    class_reminder_minutes INTEGER NOT NULL DEFAULT 60,
    meeting_join_window_minutes INTEGER NOT NULL DEFAULT 15,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_settings_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_settings_2 UNIQUE (organization_id),
    CONSTRAINT fk_organization_settings_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_settings_1 CHECK (default_currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_organization_settings_2 CHECK (jsonb_typeof(social_links) = 'object'),
    CONSTRAINT ck_organization_settings_3 CHECK (class_reminder_minutes BETWEEN 0 AND 10080),
    CONSTRAINT ck_organization_settings_4 CHECK (meeting_join_window_minutes BETWEEN 0 AND 120)
);

-- statement-breakpoint

COMMENT ON TABLE organization_settings IS 'Typed operational preferences; flexible contact/social content remains validated JSON.';

-- statement-breakpoint

CREATE INDEX ix_organization_settings_1 ON organization_settings (organization_id);

-- statement-breakpoint

CREATE TABLE plans (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    price_amount BIGINT NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    billing_interval TEXT NOT NULL DEFAULT 'MONTH',
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    is_public BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_plans_1 UNIQUE (slug),
    CONSTRAINT ck_plans_1 CHECK (price_amount >= 0),
    CONSTRAINT ck_plans_2 CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_plans_3 CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_plans_4 CHECK (billing_interval IN ('TRIAL', 'MONTH', 'YEAR')),
    CONSTRAINT ck_plans_5 CHECK (status IN ('ACTIVE', 'COMING_SOON', 'ARCHIVED'))
);

-- statement-breakpoint

COMMENT ON TABLE plans IS 'Database-driven platform subscription catalogue; amounts are integer minor currency units.';

-- statement-breakpoint

CREATE TABLE plan_features (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL,
    feature_key TEXT NOT NULL,
    value_type TEXT NOT NULL DEFAULT 'BOOLEAN',
    boolean_value BOOLEAN,
    integer_value BIGINT,
    text_value TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_plan_features_1 UNIQUE (plan_id, feature_key),
    CONSTRAINT fk_plan_features_1 FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE RESTRICT,
    CONSTRAINT ck_plan_features_1 CHECK (feature_key ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT ck_plan_features_2 CHECK ((value_type = 'BOOLEAN' AND boolean_value IS NOT NULL AND integer_value IS NULL AND text_value IS NULL) OR (value_type = 'INTEGER' AND boolean_value IS NULL AND integer_value IS NOT NULL AND text_value IS NULL) OR (value_type = 'TEXT' AND boolean_value IS NULL AND integer_value IS NULL AND text_value IS NOT NULL)),
    CONSTRAINT ck_plan_features_3 CHECK (integer_value IS NULL OR integer_value >= -1),
    CONSTRAINT ck_plan_features_4 CHECK (value_type IN ('BOOLEAN', 'INTEGER', 'TEXT'))
);

-- statement-breakpoint

COMMENT ON TABLE plan_features IS 'Typed entitlements read by one centralized authorization/usage service.';

-- statement-breakpoint

CREATE TABLE organization_subscriptions (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    plan_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'TRIAL',
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at TIMESTAMPTZ,
    trial_starts_at TIMESTAMPTZ DEFAULT now(),
    trial_ends_at TIMESTAMPTZ DEFAULT now() + interval '30 days',
    cancelled_at TIMESTAMPTZ,
    payment_provider TEXT,
    provider_subscription_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_subscriptions_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_subscriptions_2 UNIQUE (organization_id),
    CONSTRAINT uq_organization_subscriptions_3 UNIQUE (payment_provider, provider_subscription_id),
    CONSTRAINT fk_organization_subscriptions_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_subscriptions_2 FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_subscriptions_1 CHECK (ends_at IS NULL OR ends_at > starts_at),
    CONSTRAINT ck_organization_subscriptions_2 CHECK ((trial_starts_at IS NULL AND trial_ends_at IS NULL) OR (trial_starts_at IS NOT NULL AND trial_ends_at IS NOT NULL AND trial_ends_at > trial_starts_at)),
    CONSTRAINT ck_organization_subscriptions_3 CHECK (status <> 'TRIAL' OR (trial_starts_at IS NOT NULL AND trial_ends_at IS NOT NULL)),
    CONSTRAINT ck_organization_subscriptions_4 CHECK ((provider_subscription_id IS NULL) OR (payment_provider IS NOT NULL)),
    CONSTRAINT ck_organization_subscriptions_5 CHECK (status IN ('TRIAL', 'ACTIVE', 'PAST_DUE', 'EXPIRED', 'CANCELLED', 'SUSPENDED'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_subscriptions IS 'Current platform subscription per tenant; historical transitions remain in organization_subscription_history and audit logs. Student purchases never use this table.';

-- statement-breakpoint

CREATE INDEX ix_organization_subscriptions_1 ON organization_subscriptions (organization_id);

-- statement-breakpoint

CREATE INDEX ix_organization_subscriptions_2 ON organization_subscriptions (status, trial_ends_at);

-- statement-breakpoint

CREATE TABLE organization_subscription_history (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    subscription_id UUID NOT NULL,
    plan_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ,
    trial_starts_at TIMESTAMPTZ,
    trial_ends_at TIMESTAMPTZ,
    price_amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    billing_interval TEXT NOT NULL,
    feature_snapshot JSONB NOT NULL,
    changed_by UUID,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_subscription_history_1 UNIQUE (organization_id, id),
    CONSTRAINT fk_organization_subscription_history_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_subscription_history_2 FOREIGN KEY (organization_id, subscription_id) REFERENCES organization_subscriptions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_subscription_history_3 FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_subscription_history_4 FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_subscription_history_1 CHECK (price_amount >= 0),
    CONSTRAINT ck_organization_subscription_history_2 CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_organization_subscription_history_3 CHECK (jsonb_typeof(feature_snapshot) = 'object'),
    CONSTRAINT ck_organization_subscription_history_4 CHECK (status IN ('TRIAL','ACTIVE','PAST_DUE','EXPIRED','CANCELLED','SUSPENDED')),
    CONSTRAINT ck_organization_subscription_history_5 CHECK (billing_interval IN ('TRIAL','MONTH','YEAR')),
    CONSTRAINT ck_organization_subscription_history_6 CHECK (ends_at IS NULL OR ends_at > starts_at)
);

-- statement-breakpoint

COMMENT ON TABLE organization_subscription_history IS 'Append-only subscription transition snapshots; preserve past plan periods, amounts and effective access.';

-- statement-breakpoint

CREATE INDEX ix_organization_subscription_history_1 ON organization_subscription_history (organization_id);

-- statement-breakpoint

CREATE INDEX ix_organization_subscription_history_2 ON organization_subscription_history (organization_id, created_at DESC);

-- statement-breakpoint

CREATE TABLE media_assets (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    uploaded_by UUID NOT NULL,
    storage_provider TEXT NOT NULL,
    object_key TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    url TEXT,
    visibility TEXT NOT NULL DEFAULT 'PRIVATE',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_media_assets_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_media_assets_2 UNIQUE (storage_provider, object_key),
    CONSTRAINT fk_media_assets_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_media_assets_2 FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_media_assets_1 CHECK (file_size > 0),
    CONSTRAINT ck_media_assets_2 CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT ck_media_assets_3 CHECK (visibility IN ('PRIVATE', 'PUBLIC'))
);

-- statement-breakpoint

COMMENT ON TABLE media_assets IS 'External-object metadata; PostgreSQL stores neither image binaries nor signed URLs.';

-- statement-breakpoint

CREATE INDEX ix_media_assets_1 ON media_assets (organization_id);

-- statement-breakpoint

CREATE TABLE class_types (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_class_types_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_class_types_2 UNIQUE (organization_id, slug),
    CONSTRAINT fk_class_types_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_class_types_1 CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_class_types_2 CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

-- statement-breakpoint

COMMENT ON TABLE class_types IS 'Tenant-specific classification; no industry-specific application rules.';

-- statement-breakpoint

CREATE INDEX ix_class_types_1 ON class_types (organization_id);

-- statement-breakpoint

CREATE TABLE sessions (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    class_type_id UUID NOT NULL,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    short_description TEXT,
    description TEXT,
    session_type TEXT NOT NULL DEFAULT 'GROUP',
    visibility TEXT NOT NULL DEFAULT 'PRIVATE',
    status TEXT NOT NULL DEFAULT 'DRAFT',
    capacity INTEGER,
    minimum_age SMALLINT,
    maximum_age SMALLINT,
    skill_level TEXT,
    language TEXT,
    duration_minutes INTEGER NOT NULL,
    cover_image_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_sessions_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_sessions_2 UNIQUE (organization_id, slug),
    CONSTRAINT fk_sessions_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_sessions_2 FOREIGN KEY (organization_id, class_type_id) REFERENCES class_types (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_sessions_3 FOREIGN KEY (organization_id, cover_image_id) REFERENCES media_assets (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_sessions_1 CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_sessions_2 CHECK (capacity IS NULL OR capacity > 0),
    CONSTRAINT ck_sessions_3 CHECK (duration_minutes BETWEEN 1 AND 1440),
    CONSTRAINT ck_sessions_4 CHECK (minimum_age IS NULL OR minimum_age BETWEEN 0 AND 150),
    CONSTRAINT ck_sessions_5 CHECK (maximum_age IS NULL OR maximum_age BETWEEN 0 AND 150),
    CONSTRAINT ck_sessions_6 CHECK (minimum_age IS NULL OR maximum_age IS NULL OR maximum_age >= minimum_age),
    CONSTRAINT ck_sessions_7 CHECK (session_type IN ('GROUP', 'ONE_TO_ONE', 'WORKSHOP', 'PROGRAM')),
    CONSTRAINT ck_sessions_8 CHECK (visibility IN ('PUBLIC', 'PRIVATE', 'UNLISTED')),
    CONSTRAINT ck_sessions_9 CHECK (status IN ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED'))
);

-- statement-breakpoint

COMMENT ON TABLE sessions IS 'Sellable session or program; actual dated classes are class_occurrences.';

-- statement-breakpoint

CREATE INDEX ix_sessions_1 ON sessions (organization_id);

-- statement-breakpoint

CREATE INDEX ix_sessions_2 ON sessions (organization_id, status, visibility) WHERE deleted_at IS NULL;

-- statement-breakpoint

CREATE INDEX ix_sessions_3 ON sessions (organization_id, class_type_id);

-- statement-breakpoint

CREATE TABLE session_instructors (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    session_id UUID NOT NULL,
    organization_member_id UUID NOT NULL,
    role TEXT NOT NULL DEFAULT 'PRIMARY',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_session_instructors_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_session_instructors_2 UNIQUE (organization_id, session_id, organization_member_id),
    CONSTRAINT fk_session_instructors_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_instructors_2 FOREIGN KEY (organization_id, session_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_instructors_3 FOREIGN KEY (organization_id, organization_member_id) REFERENCES organization_members (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_session_instructors_1 CHECK (role IN ('PRIMARY', 'SECONDARY', 'SUBSTITUTE'))
);

-- statement-breakpoint

COMMENT ON TABLE session_instructors IS 'Staff assignment with primary, secondary or substitute responsibilities.';

-- statement-breakpoint

CREATE INDEX ix_session_instructors_1 ON session_instructors (organization_id);

-- statement-breakpoint

CREATE INDEX ix_session_instructors_2 ON session_instructors (organization_id, organization_member_id);

-- statement-breakpoint

CREATE INDEX ix_session_instructors_3 ON session_instructors (organization_id, session_id);

-- statement-breakpoint

CREATE UNIQUE INDEX ix_session_instructors_4 ON session_instructors (organization_id, session_id) WHERE role = 'PRIMARY';

-- statement-breakpoint

CREATE TABLE session_pricing (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    session_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    pricing_type TEXT NOT NULL DEFAULT 'ONE_TIME',
    amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    access_type TEXT NOT NULL DEFAULT 'DATE_RANGE',
    access_duration_days INTEGER,
    included_class_count INTEGER,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_session_pricing_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_session_pricing_2 UNIQUE (organization_id, session_id, id),
    CONSTRAINT fk_session_pricing_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_pricing_2 FOREIGN KEY (organization_id, session_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_session_pricing_1 CHECK (amount >= 0),
    CONSTRAINT ck_session_pricing_2 CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_session_pricing_3 CHECK (access_duration_days IS NULL OR access_duration_days > 0),
    CONSTRAINT ck_session_pricing_4 CHECK (included_class_count IS NULL OR included_class_count > 0),
    CONSTRAINT ck_session_pricing_5 CHECK ((access_type = 'DATE_RANGE' AND access_duration_days IS NOT NULL AND included_class_count IS NULL) OR (access_type = 'NUMBER_OF_CLASSES' AND included_class_count IS NOT NULL AND access_duration_days IS NULL) OR (access_type IN ('PROGRAM_DURATION','UNLIMITED') AND access_duration_days IS NULL AND included_class_count IS NULL)),
    CONSTRAINT ck_session_pricing_6 CHECK (pricing_type IN ('ONE_TIME', 'MONTHLY', 'PACKAGE', 'PER_SESSION', 'CUSTOM')),
    CONSTRAINT ck_session_pricing_7 CHECK (access_type IN ('DATE_RANGE', 'NUMBER_OF_CLASSES', 'PROGRAM_DURATION', 'UNLIMITED')),
    CONSTRAINT ck_session_pricing_8 CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

-- statement-breakpoint

COMMENT ON TABLE session_pricing IS 'Versionable access/pricing options; purchased values are copied into order items and enrollments.';

-- statement-breakpoint

CREATE INDEX ix_session_pricing_1 ON session_pricing (organization_id);

-- statement-breakpoint

CREATE INDEX ix_session_pricing_2 ON session_pricing (organization_id, session_id, status);

-- statement-breakpoint

CREATE TABLE session_requirements (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    session_id UUID NOT NULL,
    requirement_type TEXT NOT NULL DEFAULT 'PREREQUISITE',
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    is_required BOOLEAN NOT NULL DEFAULT false,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_session_requirements_1 UNIQUE (organization_id, id),
    CONSTRAINT fk_session_requirements_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_requirements_2 FOREIGN KEY (organization_id, session_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_session_requirements_1 CHECK (display_order >= 0),
    CONSTRAINT ck_session_requirements_2 CHECK (requirement_type IN ('PREREQUISITE', 'EQUIPMENT', 'PREPARATION', 'NOTE'))
);

-- statement-breakpoint

COMMENT ON TABLE session_requirements IS 'Structured public prerequisites, equipment, preparation and notes.';

-- statement-breakpoint

CREATE INDEX ix_session_requirements_1 ON session_requirements (organization_id);

-- statement-breakpoint

CREATE INDEX ix_session_requirements_2 ON session_requirements (organization_id, session_id, display_order);

-- statement-breakpoint

CREATE TABLE session_schedule_rules (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    session_id UUID NOT NULL,
    recurrence_type TEXT NOT NULL DEFAULT 'WEEKLY',
    day_of_week SMALLINT,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    end_day_offset SMALLINT NOT NULL DEFAULT 0,
    timezone TEXT NOT NULL,
    effective_from DATE NOT NULL,
    effective_until DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    dst_fold_policy TEXT NOT NULL DEFAULT 'EARLIER',
    dst_gap_policy TEXT NOT NULL DEFAULT 'SKIP',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_session_schedule_rules_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_session_schedule_rules_2 UNIQUE (organization_id, session_id, id),
    CONSTRAINT fk_session_schedule_rules_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_schedule_rules_2 FOREIGN KEY (organization_id, session_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_session_schedule_rules_1 CHECK ((recurrence_type = 'WEEKLY' AND day_of_week IS NOT NULL AND day_of_week BETWEEN 1 AND 7) OR (recurrence_type = 'ONE_TIME' AND day_of_week IS NULL)),
    CONSTRAINT ck_session_schedule_rules_2 CHECK ((end_day_offset = 0 AND end_time > start_time) OR (end_day_offset = 1 AND end_time <= start_time)),
    CONSTRAINT ck_session_schedule_rules_3 CHECK (effective_until IS NULL OR effective_until >= effective_from),
    CONSTRAINT ck_session_schedule_rules_4 CHECK (dst_fold_policy IN ('EARLIER','LATER')),
    CONSTRAINT ck_session_schedule_rules_5 CHECK (dst_gap_policy = 'SKIP'),
    CONSTRAINT ck_session_schedule_rules_6 CHECK (recurrence_type IN ('WEEKLY', 'ONE_TIME')),
    CONSTRAINT ck_session_schedule_rules_7 CHECK (end_day_offset IN (0, 1))
);

-- statement-breakpoint

COMMENT ON TABLE session_schedule_rules IS 'Finite or open-ended weekly/local rules expanded only over a bounded rolling horizon. Local wall times intentionally use TIME and DATE.';

-- statement-breakpoint

CREATE INDEX ix_session_schedule_rules_1 ON session_schedule_rules (organization_id);

-- statement-breakpoint

CREATE INDEX ix_session_schedule_rules_2 ON session_schedule_rules (organization_id, session_id, is_active);

-- statement-breakpoint

CREATE TABLE organization_integrations (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    provider TEXT NOT NULL,
    account_identifier TEXT NOT NULL,
    encrypted_credentials BYTEA,
    encryption_key_id TEXT,
    configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'DISCONNECTED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_integrations_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_integrations_2 UNIQUE (organization_id, provider, account_identifier),
    CONSTRAINT fk_organization_integrations_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_integrations_1 CHECK (jsonb_typeof(configuration) = 'object'),
    CONSTRAINT ck_organization_integrations_2 CHECK ((encrypted_credentials IS NULL) = (encryption_key_id IS NULL)),
    CONSTRAINT ck_organization_integrations_3 CHECK (status IN ('CONNECTED', 'DISCONNECTED', 'ERROR'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_integrations IS 'Provider-neutral connected accounts; encrypted tokens remain inaccessible to browser/public response models.';

-- statement-breakpoint

CREATE INDEX ix_organization_integrations_1 ON organization_integrations (organization_id);

-- statement-breakpoint

CREATE TABLE class_occurrences (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    session_id UUID NOT NULL,
    schedule_rule_id UUID,
    original_start_at TIMESTAMPTZ NOT NULL,
    original_end_at TIMESTAMPTZ NOT NULL,
    actual_start_at TIMESTAMPTZ NOT NULL,
    actual_end_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'SCHEDULED',
    meeting_provider TEXT,
    meeting_id TEXT,
    meeting_join_url TEXT,
    meeting_host_url_ciphertext BYTEA,
    integration_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_class_occurrences_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_class_occurrences_2 UNIQUE (organization_id, session_id, id),
    CONSTRAINT uq_class_occurrences_3 UNIQUE (organization_id, session_id, schedule_rule_id, original_start_at),
    CONSTRAINT fk_class_occurrences_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_class_occurrences_2 FOREIGN KEY (organization_id, session_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_class_occurrences_3 FOREIGN KEY (organization_id, session_id, schedule_rule_id) REFERENCES session_schedule_rules (organization_id, session_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_class_occurrences_4 FOREIGN KEY (organization_id, integration_id) REFERENCES organization_integrations (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_class_occurrences_1 CHECK (original_end_at > original_start_at),
    CONSTRAINT ck_class_occurrences_2 CHECK (actual_end_at > actual_start_at),
    CONSTRAINT ck_class_occurrences_3 CHECK (meeting_join_url IS NULL OR meeting_provider IS NOT NULL),
    CONSTRAINT ck_class_occurrences_4 CHECK (status IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'POSTPONED', 'RESCHEDULED'))
);

-- statement-breakpoint

COMMENT ON TABLE class_occurrences IS 'Dated execution of a session. Original time is immutable; actual time changes during rescheduling.';

-- statement-breakpoint

CREATE INDEX ix_class_occurrences_1 ON class_occurrences (organization_id);

-- statement-breakpoint

CREATE INDEX ix_class_occurrences_2 ON class_occurrences (organization_id, actual_start_at, id);

-- statement-breakpoint

CREATE INDEX ix_class_occurrences_3 ON class_occurrences (organization_id, session_id, actual_start_at);

-- statement-breakpoint

CREATE INDEX ix_class_occurrences_4 ON class_occurrences (status, actual_start_at);

-- statement-breakpoint

CREATE TABLE class_occurrence_changes (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    class_occurrence_id UUID NOT NULL,
    change_type TEXT NOT NULL DEFAULT 'UPDATED',
    previous_data JSONB,
    new_data JSONB NOT NULL,
    reason TEXT,
    changed_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_class_occurrence_changes_1 UNIQUE (organization_id, id),
    CONSTRAINT fk_class_occurrence_changes_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_class_occurrence_changes_2 FOREIGN KEY (organization_id, class_occurrence_id) REFERENCES class_occurrences (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_class_occurrence_changes_3 FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_class_occurrence_changes_1 CHECK (jsonb_typeof(new_data) = 'object'),
    CONSTRAINT ck_class_occurrence_changes_2 CHECK (change_type IN ('CREATED', 'CANCELLED', 'RESCHEDULED', 'POSTPONED', 'UPDATED'))
);

-- statement-breakpoint

COMMENT ON TABLE class_occurrence_changes IS 'Immutable cancellation/rescheduling history; redacted snapshots never include meeting secrets.';

-- statement-breakpoint

CREATE INDEX ix_class_occurrence_changes_1 ON class_occurrence_changes (organization_id);

-- statement-breakpoint

CREATE INDEX ix_class_occurrence_changes_2 ON class_occurrence_changes (organization_id, class_occurrence_id, created_at);

-- statement-breakpoint

CREATE TABLE organization_payment_accounts (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    provider TEXT NOT NULL,
    provider_account_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_payment_accounts_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_payment_accounts_2 UNIQUE (provider, provider_account_id),
    CONSTRAINT fk_organization_payment_accounts_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_payment_accounts_1 CHECK (jsonb_typeof(configuration) = 'object'),
    CONSTRAINT ck_organization_payment_accounts_2 CHECK (status IN ('PENDING', 'ACTIVE', 'RESTRICTED', 'DISABLED'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_payment_accounts IS 'Organization-owned settlement destination, independent of platform subscription billing.';

-- statement-breakpoint

CREATE INDEX ix_organization_payment_accounts_1 ON organization_payment_accounts (organization_id);

-- statement-breakpoint

CREATE TABLE orders (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    organization_student_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    subtotal_amount BIGINT NOT NULL,
    discount_amount BIGINT NOT NULL DEFAULT 0,
    tax_amount BIGINT NOT NULL DEFAULT 0,
    total_amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    payment_status TEXT NOT NULL DEFAULT 'UNPAID',
    idempotency_key TEXT NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_orders_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_orders_2 UNIQUE (organization_id, idempotency_key),
    CONSTRAINT uq_orders_3 UNIQUE (organization_id, id, organization_student_id),
    CONSTRAINT fk_orders_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_orders_2 FOREIGN KEY (organization_id, organization_student_id) REFERENCES organization_students (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_orders_1 CHECK (subtotal_amount >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0),
    CONSTRAINT ck_orders_2 CHECK (discount_amount <= subtotal_amount),
    CONSTRAINT ck_orders_3 CHECK (total_amount = subtotal_amount - discount_amount + tax_amount),
    CONSTRAINT ck_orders_4 CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_orders_5 CHECK (status IN ('PENDING', 'PAYMENT_PENDING', 'PAID', 'FAILED', 'CANCELLED', 'REFUNDED', 'PARTIALLY_REFUNDED')),
    CONSTRAINT ck_orders_6 CHECK (payment_status IN ('UNPAID', 'PENDING', 'PAID', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED'))
);

-- statement-breakpoint

COMMENT ON TABLE orders IS 'Student commerce order with server-computed totals and a tenant-local student relationship.';

-- statement-breakpoint

CREATE INDEX ix_orders_1 ON orders (organization_id);

-- statement-breakpoint

CREATE INDEX ix_orders_2 ON orders (organization_id, organization_student_id, created_at DESC);

-- statement-breakpoint

CREATE INDEX ix_orders_3 ON orders (organization_id, status, created_at);

-- statement-breakpoint

CREATE TABLE order_items (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    order_id UUID NOT NULL,
    purchasable_type TEXT NOT NULL DEFAULT 'SESSION',
    purchasable_id UUID NOT NULL,
    pricing_id UUID NOT NULL,
    name_snapshot TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price BIGINT NOT NULL,
    total_price BIGINT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_order_items_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_order_items_2 UNIQUE (organization_id, id, order_id, purchasable_id, pricing_id),
    CONSTRAINT fk_order_items_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_2 FOREIGN KEY (organization_id, order_id) REFERENCES orders (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_3 FOREIGN KEY (organization_id, purchasable_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_4 FOREIGN KEY (organization_id, purchasable_id, pricing_id) REFERENCES session_pricing (organization_id, session_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_order_items_1 CHECK (quantity = 1),
    CONSTRAINT ck_order_items_2 CHECK (unit_price >= 0 AND total_price >= 0),
    CONSTRAINT ck_order_items_3 CHECK (total_price = quantity * unit_price),
    CONSTRAINT ck_order_items_4 CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT ck_order_items_5 CHECK (purchasable_type IN ('SESSION'))
);

-- statement-breakpoint

COMMENT ON TABLE order_items IS 'Immutable purchased session/pricing snapshot. Initial SESSION target has a real FK; other product types require an explicit migration.';

-- statement-breakpoint

CREATE INDEX ix_order_items_1 ON order_items (organization_id);

-- statement-breakpoint

CREATE INDEX ix_order_items_2 ON order_items (organization_id, order_id);

-- statement-breakpoint

CREATE TABLE payments (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    organization_student_id UUID NOT NULL,
    order_id UUID NOT NULL,
    payment_account_id UUID,
    provider TEXT NOT NULL,
    provider_payment_id TEXT,
    provider_order_id TEXT NOT NULL,
    amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'CREATED',
    payment_method TEXT,
    provider_response JSONB NOT NULL DEFAULT '{}'::jsonb,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_payments_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_payments_2 UNIQUE (provider, provider_payment_id),
    CONSTRAINT uq_payments_3 UNIQUE (organization_id, id, order_id),
    CONSTRAINT fk_payments_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_payments_2 FOREIGN KEY (organization_id, organization_student_id) REFERENCES organization_students (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_payments_3 FOREIGN KEY (organization_id, order_id, organization_student_id) REFERENCES orders (organization_id, id, organization_student_id) ON DELETE RESTRICT,
    CONSTRAINT fk_payments_4 FOREIGN KEY (organization_id, payment_account_id) REFERENCES organization_payment_accounts (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_payments_1 CHECK (amount >= 0),
    CONSTRAINT ck_payments_2 CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_payments_3 CHECK (jsonb_typeof(provider_response) = 'object'),
    CONSTRAINT ck_payments_4 CHECK (status IN ('CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED'))
);

-- statement-breakpoint

COMMENT ON TABLE payments IS 'Provider-confirmed movement for a student order; provider IDs are globally idempotent per provider.';

-- statement-breakpoint

CREATE INDEX ix_payments_1 ON payments (organization_id);

-- statement-breakpoint

CREATE INDEX ix_payments_2 ON payments (organization_id, order_id);

-- statement-breakpoint

CREATE INDEX ix_payments_3 ON payments (provider, provider_order_id);

-- statement-breakpoint

CREATE INDEX ix_payments_4 ON payments (organization_id, paid_at);

-- statement-breakpoint

CREATE TABLE payment_attempts (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    order_id UUID NOT NULL,
    payment_id UUID,
    provider TEXT NOT NULL,
    provider_order_id TEXT,
    idempotency_key TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'CREATED',
    error_code TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_attempts_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_payment_attempts_2 UNIQUE (organization_id, idempotency_key),
    CONSTRAINT uq_payment_attempts_3 UNIQUE (provider, provider_order_id),
    CONSTRAINT fk_payment_attempts_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_payment_attempts_2 FOREIGN KEY (organization_id, order_id) REFERENCES orders (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_payment_attempts_3 FOREIGN KEY (organization_id, payment_id, order_id) REFERENCES payments (organization_id, id, order_id) ON DELETE RESTRICT,
    CONSTRAINT ck_payment_attempts_1 CHECK (status IN ('CREATED', 'PENDING', 'SUCCEEDED', 'FAILED'))
);

-- statement-breakpoint

COMMENT ON TABLE payment_attempts IS 'One traceable provider checkout initiation attempt with redacted failure diagnostics.';

-- statement-breakpoint

CREATE INDEX ix_payment_attempts_1 ON payment_attempts (organization_id);

-- statement-breakpoint

CREATE INDEX ix_payment_attempts_2 ON payment_attempts (organization_id, order_id, created_at);

-- statement-breakpoint

CREATE TABLE refunds (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    payment_id UUID NOT NULL,
    order_id UUID NOT NULL,
    provider TEXT NOT NULL,
    provider_refund_id TEXT,
    idempotency_key TEXT NOT NULL,
    amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    status TEXT NOT NULL DEFAULT 'REQUESTED',
    reason TEXT,
    requested_by UUID NOT NULL,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_refunds_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_refunds_2 UNIQUE (provider, provider_refund_id),
    CONSTRAINT uq_refunds_3 UNIQUE (organization_id, idempotency_key),
    CONSTRAINT fk_refunds_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_refunds_2 FOREIGN KEY (organization_id, payment_id, order_id) REFERENCES payments (organization_id, id, order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_refunds_3 FOREIGN KEY (organization_id, order_id) REFERENCES orders (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_refunds_4 FOREIGN KEY (requested_by) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT ck_refunds_1 CHECK (amount > 0),
    CONSTRAINT ck_refunds_2 CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_refunds_3 CHECK (status IN ('REQUESTED', 'PROCESSING', 'SUCCEEDED', 'FAILED'))
);

-- statement-breakpoint

COMMENT ON TABLE refunds IS 'Idempotent refund request and provider outcome. Aggregate refund amount is checked transactionally under payment lock.';

-- statement-breakpoint

CREATE INDEX ix_refunds_1 ON refunds (organization_id);

-- statement-breakpoint

CREATE INDEX ix_refunds_2 ON refunds (organization_id, payment_id);

-- statement-breakpoint

CREATE TABLE payment_webhook_events (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID,
    order_id UUID,
    provider TEXT NOT NULL,
    event_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    payload_sha256 TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'RECEIVED',
    attempts INTEGER NOT NULL DEFAULT 0,
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_webhook_events_1 UNIQUE (provider, event_id),
    CONSTRAINT fk_payment_webhook_events_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_payment_webhook_events_2 FOREIGN KEY (organization_id, order_id) REFERENCES orders (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_payment_webhook_events_1 CHECK (attempts >= 0),
    CONSTRAINT ck_payment_webhook_events_2 CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT ck_payment_webhook_events_3 CHECK (order_id IS NULL OR organization_id IS NOT NULL),
    CONSTRAINT ck_payment_webhook_events_4 CHECK (status IN ('RECEIVED', 'PROCESSING', 'PROCESSED', 'FAILED', 'IGNORED'))
);

-- statement-breakpoint

COMMENT ON TABLE payment_webhook_events IS 'Verified provider webhook inbox. Organization/order are resolved from trusted provider order references, never caller tenant claims.';

-- statement-breakpoint

CREATE INDEX ix_payment_webhook_events_1 ON payment_webhook_events (status, created_at);

-- statement-breakpoint

CREATE INDEX ix_payment_webhook_events_2 ON payment_webhook_events (organization_id, order_id);

-- statement-breakpoint

CREATE TABLE session_enrollments (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    organization_student_id UUID NOT NULL,
    session_id UUID NOT NULL,
    pricing_id UUID NOT NULL,
    order_id UUID NOT NULL,
    order_item_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    access_type TEXT NOT NULL DEFAULT 'DATE_RANGE',
    access_starts_at TIMESTAMPTZ NOT NULL,
    access_ends_at TIMESTAMPTZ,
    included_class_count INTEGER,
    remaining_class_count INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_session_enrollments_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_session_enrollments_2 UNIQUE (order_item_id),
    CONSTRAINT uq_session_enrollments_3 UNIQUE (organization_id, id, session_id, organization_student_id),
    CONSTRAINT fk_session_enrollments_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_enrollments_2 FOREIGN KEY (organization_id, organization_student_id) REFERENCES organization_students (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_enrollments_3 FOREIGN KEY (organization_id, session_id) REFERENCES sessions (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_enrollments_4 FOREIGN KEY (organization_id, session_id, pricing_id) REFERENCES session_pricing (organization_id, session_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_enrollments_5 FOREIGN KEY (organization_id, order_id, organization_student_id) REFERENCES orders (organization_id, id, organization_student_id) ON DELETE RESTRICT,
    CONSTRAINT fk_session_enrollments_6 FOREIGN KEY (organization_id, order_item_id, order_id, session_id, pricing_id) REFERENCES order_items (organization_id, id, order_id, purchasable_id, pricing_id) ON DELETE RESTRICT,
    CONSTRAINT ck_session_enrollments_1 CHECK (access_ends_at IS NULL OR access_ends_at > access_starts_at),
    CONSTRAINT ck_session_enrollments_2 CHECK ((access_type = 'NUMBER_OF_CLASSES' AND included_class_count IS NOT NULL AND remaining_class_count IS NOT NULL AND included_class_count > 0 AND remaining_class_count BETWEEN 0 AND included_class_count) OR (access_type <> 'NUMBER_OF_CLASSES' AND included_class_count IS NULL AND remaining_class_count IS NULL)),
    CONSTRAINT ck_session_enrollments_3 CHECK (access_type NOT IN ('DATE_RANGE','PROGRAM_DURATION') OR access_ends_at IS NOT NULL),
    CONSTRAINT ck_session_enrollments_4 CHECK (status IN ('PENDING', 'ACTIVE', 'PAUSED', 'EXPIRED', 'CANCELLED', 'COMPLETED')),
    CONSTRAINT ck_session_enrollments_5 CHECK (access_type IN ('DATE_RANGE', 'NUMBER_OF_CLASSES', 'PROGRAM_DURATION', 'UNLIMITED'))
);

-- statement-breakpoint

COMMENT ON TABLE session_enrollments IS 'Purchased access grant; each order item activates at most once. Renewal creates another grant and preserves prior payment history.';

-- statement-breakpoint

CREATE INDEX ix_session_enrollments_1 ON session_enrollments (organization_id);

-- statement-breakpoint

CREATE INDEX ix_session_enrollments_2 ON session_enrollments (organization_id, organization_student_id, status);

-- statement-breakpoint

CREATE INDEX ix_session_enrollments_3 ON session_enrollments (organization_id, session_id, status);

-- statement-breakpoint

CREATE INDEX ix_session_enrollments_4 ON session_enrollments (status, access_ends_at);

-- statement-breakpoint

CREATE TABLE attendance_records (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    class_occurrence_id UUID NOT NULL,
    session_id UUID NOT NULL,
    organization_student_id UUID NOT NULL,
    enrollment_id UUID NOT NULL,
    status TEXT NOT NULL DEFAULT 'PRESENT',
    marked_by UUID NOT NULL,
    marked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_attendance_records_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_attendance_records_2 UNIQUE (organization_id, class_occurrence_id, organization_student_id),
    CONSTRAINT uq_attendance_records_3 UNIQUE (organization_id, id, enrollment_id),
    CONSTRAINT fk_attendance_records_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_records_2 FOREIGN KEY (organization_id, session_id, class_occurrence_id) REFERENCES class_occurrences (organization_id, session_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_records_3 FOREIGN KEY (organization_id, organization_student_id) REFERENCES organization_students (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_records_4 FOREIGN KEY (organization_id, enrollment_id, session_id, organization_student_id) REFERENCES session_enrollments (organization_id, id, session_id, organization_student_id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_records_5 FOREIGN KEY (organization_id, marked_by) REFERENCES organization_members (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_attendance_records_1 CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED'))
);

-- statement-breakpoint

COMMENT ON TABLE attendance_records IS 'One attendance decision per student and occurrence; links the precise enrollment used for access.';

-- statement-breakpoint

CREATE INDEX ix_attendance_records_1 ON attendance_records (organization_id);

-- statement-breakpoint

CREATE INDEX ix_attendance_records_2 ON attendance_records (organization_id, enrollment_id);

-- statement-breakpoint

CREATE INDEX ix_attendance_records_3 ON attendance_records (organization_id, organization_student_id, marked_at);

-- statement-breakpoint

CREATE TABLE attendance_consumptions (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    attendance_record_id UUID NOT NULL,
    enrollment_id UUID NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reversed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_attendance_consumptions_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_attendance_consumptions_2 UNIQUE (attendance_record_id),
    CONSTRAINT fk_attendance_consumptions_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_consumptions_2 FOREIGN KEY (organization_id, attendance_record_id, enrollment_id) REFERENCES attendance_records (organization_id, id, enrollment_id) ON DELETE RESTRICT,
    CONSTRAINT fk_attendance_consumptions_3 FOREIGN KEY (organization_id, enrollment_id) REFERENCES session_enrollments (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_attendance_consumptions_1 CHECK (reversed_at IS NULL OR reversed_at >= consumed_at)
);

-- statement-breakpoint

COMMENT ON TABLE attendance_consumptions IS 'Idempotent package usage ledger. Lock enrollment and ledger before toggling consumed state or restoring a class.';

-- statement-breakpoint

CREATE INDEX ix_attendance_consumptions_1 ON attendance_consumptions (organization_id);

-- statement-breakpoint

CREATE INDEX ix_attendance_consumptions_2 ON attendance_consumptions (organization_id, enrollment_id);

-- statement-breakpoint

CREATE TABLE website_templates (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    preview_image_url TEXT,
    template_version INTEGER NOT NULL DEFAULT 1,
    is_available BOOLEAN NOT NULL DEFAULT true,
    configuration_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_website_templates_1 UNIQUE (slug, template_version),
    CONSTRAINT ck_website_templates_1 CHECK (template_version > 0),
    CONSTRAINT ck_website_templates_2 CHECK (jsonb_typeof(configuration_schema) = 'object'),
    CONSTRAINT ck_website_templates_3 CHECK (status IN ('ACTIVE', 'ARCHIVED'))
);

-- statement-breakpoint

COMMENT ON TABLE website_templates IS 'Versioned fixed-layout catalogue. Application renders templates; arbitrary HTML is forbidden.';

-- statement-breakpoint

CREATE TABLE organization_websites (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    template_id UUID,
    website_type TEXT NOT NULL DEFAULT 'DEFAULT',
    status TEXT NOT NULL DEFAULT 'DRAFT',
    configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
    published_configuration JSONB,
    published_template_id UUID,
    published_website_type TEXT,
    published_at TIMESTAMPTZ,
    seo_title TEXT,
    seo_description TEXT,
    og_image_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_websites_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_websites_2 UNIQUE (organization_id),
    CONSTRAINT fk_organization_websites_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_websites_2 FOREIGN KEY (template_id) REFERENCES website_templates (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_websites_3 FOREIGN KEY (published_template_id) REFERENCES website_templates (id) ON DELETE RESTRICT,
    CONSTRAINT fk_organization_websites_4 FOREIGN KEY (organization_id, og_image_id) REFERENCES media_assets (organization_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_websites_1 CHECK (jsonb_typeof(configuration) = 'object'),
    CONSTRAINT ck_organization_websites_2 CHECK (published_configuration IS NULL OR jsonb_typeof(published_configuration) = 'object'),
    CONSTRAINT ck_organization_websites_3 CHECK ((website_type = 'DEFAULT' AND template_id IS NULL) OR (website_type = 'ADVANCED' AND template_id IS NOT NULL)),
    CONSTRAINT ck_organization_websites_4 CHECK (published_website_type IS NULL OR published_website_type IN ('DEFAULT','ADVANCED')),
    CONSTRAINT ck_organization_websites_5 CHECK (status <> 'PUBLISHED' OR (published_at IS NOT NULL AND published_configuration IS NOT NULL AND published_website_type IS NOT NULL)),
    CONSTRAINT ck_organization_websites_6 CHECK (published_website_type <> 'ADVANCED' OR published_template_id IS NOT NULL),
    CONSTRAINT ck_organization_websites_7 CHECK (website_type IN ('DEFAULT', 'ADVANCED')),
    CONSTRAINT ck_organization_websites_8 CHECK (status IN ('DRAFT', 'PUBLISHED', 'UNPUBLISHED'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_websites IS 'Separate draft and published content snapshots prevent unreviewed edits leaking onto the public site.';

-- statement-breakpoint

CREATE INDEX ix_organization_websites_1 ON organization_websites (organization_id);

-- statement-breakpoint

CREATE TABLE organization_domains (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    hostname TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    verification_token_hash TEXT NOT NULL,
    verified_at TIMESTAMPTZ,
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_organization_domains_1 UNIQUE (organization_id, id),
    CONSTRAINT uq_organization_domains_2 UNIQUE (hostname),
    CONSTRAINT fk_organization_domains_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_organization_domains_1 CHECK (hostname = lower(btrim(hostname)) AND position('.' IN hostname) > 1),
    CONSTRAINT ck_organization_domains_2 CHECK (status IN ('PENDING', 'VERIFIED', 'ACTIVE', 'FAILED', 'DISABLED'))
);

-- statement-breakpoint

COMMENT ON TABLE organization_domains IS 'Reserved support for verified custom domains; DNS automation is deferred.';

-- statement-breakpoint

CREATE INDEX ix_organization_domains_1 ON organization_domains (organization_id);

-- statement-breakpoint

CREATE UNIQUE INDEX ix_organization_domains_2 ON organization_domains (organization_id) WHERE is_primary = true;

-- statement-breakpoint

CREATE TABLE notifications (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    organization_id UUID,
    event_type TEXT NOT NULL,
    channel TEXT NOT NULL DEFAULT 'IN_APP',
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'PENDING',
    idempotency_key TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_notifications_1 UNIQUE (user_id, channel, idempotency_key),
    CONSTRAINT fk_notifications_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_notifications_2 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_notifications_1 CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT ck_notifications_2 CHECK (channel IN ('IN_APP', 'EMAIL', 'WHATSAPP', 'SMS', 'PUSH')),
    CONSTRAINT ck_notifications_3 CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'READ'))
);

-- statement-breakpoint

COMMENT ON TABLE notifications IS 'Per-user delivery record, channel-independent. Public APIs never read this table.';

-- statement-breakpoint

CREATE INDEX ix_notifications_1 ON notifications (user_id, created_at DESC);

-- statement-breakpoint

CREATE INDEX ix_notifications_2 ON notifications (organization_id, status);

-- statement-breakpoint

CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    organization_id UUID,
    event_type TEXT NOT NULL,
    channel TEXT NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_notification_preferences_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_notification_preferences_2 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_notification_preferences_1 CHECK (channel IN ('IN_APP', 'EMAIL', 'WHATSAPP', 'SMS', 'PUSH'))
);

-- statement-breakpoint

COMMENT ON TABLE notification_preferences IS 'User-controlled event/channel preferences, optionally overridden for an organization.';

-- statement-breakpoint

CREATE UNIQUE INDEX ix_notification_preferences_1 ON notification_preferences (user_id, event_type, channel) WHERE organization_id IS NULL;

-- statement-breakpoint

CREATE UNIQUE INDEX ix_notification_preferences_2 ON notification_preferences (user_id, organization_id, event_type, channel) WHERE organization_id IS NOT NULL;

-- statement-breakpoint

CREATE TABLE outbox_events (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID,
    topic TEXT NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id UUID,
    idempotency_key TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 8,
    available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    locked_at TIMESTAMPTZ,
    locked_by TEXT,
    completed_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_outbox_events_1 UNIQUE (topic, idempotency_key),
    CONSTRAINT fk_outbox_events_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT ck_outbox_events_1 CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT ck_outbox_events_2 CHECK (attempts >= 0 AND max_attempts > 0 AND attempts <= max_attempts),
    CONSTRAINT ck_outbox_events_3 CHECK (status <> 'PROCESSING' OR (locked_at IS NOT NULL AND locked_by IS NOT NULL)),
    CONSTRAINT ck_outbox_events_4 CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'DEAD'))
);

-- statement-breakpoint

COMMENT ON TABLE outbox_events IS 'Transactional, at-least-once work queue for reliable notifications, scheduling and integrations. Workers must be idempotent.';

-- statement-breakpoint

CREATE INDEX ix_outbox_events_1 ON outbox_events (available_at, created_at) WHERE status = 'PENDING';

-- statement-breakpoint

CREATE INDEX ix_outbox_events_2 ON outbox_events (locked_at) WHERE status = 'PROCESSING';

-- statement-breakpoint

CREATE INDEX ix_outbox_events_3 ON outbox_events (organization_id, created_at);

-- statement-breakpoint

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID,
    user_id UUID,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_audit_logs_1 FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE RESTRICT,
    CONSTRAINT fk_audit_logs_2 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
);

-- statement-breakpoint

COMMENT ON TABLE audit_logs IS 'Append-only business/admin audit history; snapshots are explicitly redacted and exclude credentials, OTPs and payment secrets.';

-- statement-breakpoint

CREATE INDEX ix_audit_logs_1 ON audit_logs (organization_id, created_at DESC);

-- statement-breakpoint

CREATE INDEX ix_audit_logs_2 ON audit_logs (user_id, created_at DESC);

-- statement-breakpoint

CREATE INDEX ix_audit_logs_3 ON audit_logs (entity_type, entity_id, created_at);
