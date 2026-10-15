-- Current SQLAlchemy runtime schema. Apply changes through Alembic, not this reference DDL.
-- Updated for account roles and studio teacher assignment, September 25, 2026.

CREATE TABLE organizations (
	id UUID NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	slug VARCHAR(255) NOT NULL, 
	logo_url VARCHAR(1024), 
	timezone VARCHAR(100) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_organizations_slug ON organizations (slug);

CREATE TABLE payment_webhook_events (
	id UUID NOT NULL, 
	event_id VARCHAR(255) NOT NULL, 
	event_type VARCHAR(100) NOT NULL, 
	payload JSONB NOT NULL, 
	is_processed BOOLEAN NOT NULL, 
	processed_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_payment_webhook_events_event_id ON payment_webhook_events (event_id);

CREATE TABLE plans (
	id UUID NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	slug VARCHAR(100) NOT NULL, 
	description TEXT, 
	price NUMERIC(10, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	billing_interval VARCHAR(20) NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	is_public BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_plans_slug ON plans (slug);

CREATE TABLE users (
	id UUID NOT NULL, 
	role VARCHAR(20) DEFAULT 'STUDENT' NOT NULL, 
	username VARCHAR(100), 
	address VARCHAR(1000), 
	location VARCHAR(255), 
	email VARCHAR(255) NOT NULL, 
	phone VARCHAR(50), 
	full_name VARCHAR(255) NOT NULL, 
	avatar_url VARCHAR(1024), 
	is_active BOOLEAN NOT NULL, 
	is_superadmin BOOLEAN NOT NULL, 
	password_hash VARCHAR(255), 
	is_verified BOOLEAN NOT NULL, 
	account_status VARCHAR(50) NOT NULL, 
	last_login_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	CONSTRAINT ck_users_role CHECK (role IN ('SUPER_ADMIN', 'STUDIO', 'TEACHER', 'STUDENT')), 
	CONSTRAINT ck_users_superadmin_consistent CHECK (is_superadmin = (role = 'SUPER_ADMIN')), 
	UNIQUE (username)
);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE INDEX ix_users_role ON users (role);

CREATE UNIQUE INDEX uq_users_single_super_admin ON users (role) WHERE role = 'SUPER_ADMIN';

CREATE TABLE website_templates (
	id UUID NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	code VARCHAR(50) NOT NULL, 
	preview_image_url VARCHAR(1024), 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_website_templates_code ON website_templates (code);

CREATE TABLE audit_logs (
	id UUID NOT NULL, 
	organization_id UUID, 
	user_id UUID, 
	entity_type VARCHAR(100) NOT NULL, 
	entity_id UUID, 
	action VARCHAR(100) NOT NULL, 
	old_data JSONB, 
	new_data JSONB, 
	ip_address VARCHAR(100), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX ix_audit_logs_entity_type ON audit_logs (entity_type);

CREATE INDEX ix_audit_logs_organization_id ON audit_logs (organization_id);

CREATE INDEX ix_audit_logs_user_id ON audit_logs (user_id);

CREATE TABLE class_types (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	slug VARCHAR(255) NOT NULL, 
	description TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX ix_class_types_organization_id ON class_types (organization_id);

CREATE TABLE media_assets (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	file_name VARCHAR(255) NOT NULL, 
	file_url VARCHAR(1024) NOT NULL, 
	mime_type VARCHAR(100) NOT NULL, 
	size_bytes BIGINT NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX ix_media_assets_organization_id ON media_assets (organization_id);

CREATE TABLE notifications (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	organization_id UUID, 
	title VARCHAR(255) NOT NULL, 
	message TEXT NOT NULL, 
	type VARCHAR(50) NOT NULL, 
	is_read BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX ix_notifications_organization_id ON notifications (organization_id);

CREATE INDEX ix_notifications_user_id ON notifications (user_id);

CREATE TABLE orders (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	order_number VARCHAR(50) NOT NULL, 
	total_amount NUMERIC(10, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX ix_orders_order_number ON orders (order_number);

CREATE INDEX ix_orders_organization_id ON orders (organization_id);

CREATE INDEX ix_orders_status ON orders (status);

CREATE INDEX ix_orders_user_id ON orders (user_id);

CREATE TABLE organization_domains (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	domain_name VARCHAR(255) NOT NULL, 
	is_verified BOOLEAN NOT NULL, 
	ssl_status VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX ix_organization_domains_domain_name ON organization_domains (domain_name);

CREATE INDEX ix_organization_domains_organization_id ON organization_domains (organization_id);

CREATE TABLE organization_integrations (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	provider VARCHAR(50) NOT NULL, 
	credentials_enc TEXT, 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX ix_organization_integrations_organization_id ON organization_integrations (organization_id);

CREATE TABLE organization_members (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	role VARCHAR(50) NOT NULL, 
	title VARCHAR(100), 
	bio TEXT, 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_member UNIQUE (organization_id, user_id), 
	CONSTRAINT uq_org_member_identity UNIQUE (organization_id, id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_organization_members_organization_id ON organization_members (organization_id);

CREATE INDEX ix_organization_members_user_id ON organization_members (user_id);

CREATE TABLE organization_payment_accounts (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	provider VARCHAR(50) NOT NULL, 
	key_id VARCHAR(255) NOT NULL, 
	key_secret_enc VARCHAR(512) NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (organization_id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE organization_settings (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	brand_color VARCHAR(20), 
	support_email VARCHAR(255), 
	support_phone VARCHAR(50), 
	phone VARCHAR(50), 
	whatsapp_number VARCHAR(50), 
	studio_tagline VARCHAR(255), 
	disciplines VARCHAR(500), 
	teaching_mode VARCHAR(50) NOT NULL, 
	address_line1 VARCHAR(255), 
	address_line2 VARCHAR(255), 
	city VARCHAR(100), 
	state VARCHAR(100), 
	pincode VARCHAR(20), 
	country VARCHAR(100) NOT NULL, 
	has_gst BOOLEAN NOT NULL, 
	gst_number VARCHAR(20), 
	legal_business_name VARCHAR(255), 
	pan_number VARCHAR(20), 
	bank_name VARCHAR(100), 
	account_holder_name VARCHAR(255), 
	account_number_enc VARCHAR(255), 
	ifsc_code VARCHAR(20), 
	upi_id VARCHAR(100), 
	settlement_cycle VARCHAR(50) NOT NULL, 
	zoom_connected BOOLEAN NOT NULL, 
	zoom_account_email VARCHAR(255), 
	zoom_auto_meeting_enabled BOOLEAN NOT NULL, 
	zoom_waiting_room BOOLEAN NOT NULL, 
	zoom_host_video BOOLEAN NOT NULL, 
	account_completed BOOLEAN NOT NULL, 
	completion_step INTEGER NOT NULL, 
	completion_percentage INTEGER NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (organization_id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE organization_subscriptions (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	plan_id UUID NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	starts_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	ends_at TIMESTAMP WITH TIME ZONE, 
	trial_starts_at TIMESTAMP WITH TIME ZONE, 
	trial_ends_at TIMESTAMP WITH TIME ZONE, 
	cancelled_at TIMESTAMP WITH TIME ZONE, 
	payment_provider VARCHAR(50), 
	provider_subscription_id VARCHAR(255), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (organization_id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(plan_id) REFERENCES plans (id)
);

CREATE INDEX ix_organization_subscriptions_plan_id ON organization_subscriptions (plan_id);

CREATE TABLE organization_websites (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	template_id UUID NOT NULL, 
	headline VARCHAR(255), 
	subheadline VARCHAR(500), 
	hero_image_url VARCHAR(1024), 
	about_text TEXT, 
	primary_color VARCHAR(20) NOT NULL, 
	accent_color VARCHAR(20) NOT NULL, 
	social_links JSONB, 
	custom_sections JSONB, 
	is_published BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (organization_id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(template_id) REFERENCES website_templates (id)
);

CREATE TABLE plan_features (
	id UUID NOT NULL, 
	plan_id UUID NOT NULL, 
	feature_key VARCHAR(100) NOT NULL, 
	feature_value VARCHAR(255) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(plan_id) REFERENCES plans (id) ON DELETE CASCADE
);

CREATE INDEX ix_plan_features_feature_key ON plan_features (feature_key);

CREATE INDEX ix_plan_features_plan_id ON plan_features (plan_id);

CREATE TABLE user_auth_methods (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	auth_type VARCHAR(50) NOT NULL, 
	credential_hash VARCHAR(255), 
	otp_code VARCHAR(10), 
	otp_expires_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_user_auth_methods_user_id ON user_auth_methods (user_id);

CREATE TABLE user_otps (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	email VARCHAR(255) NOT NULL, 
	otp_hash VARCHAR(255) NOT NULL, 
	purpose VARCHAR(50) NOT NULL, 
	attempts INTEGER NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	verified_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_user_otps_email ON user_otps (email);

CREATE INDEX ix_user_otps_user_id ON user_otps (user_id);

CREATE TABLE user_sessions (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	token VARCHAR(512) NOT NULL, 
	ip_address VARCHAR(100), 
	user_agent VARCHAR(255), 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX ix_user_sessions_token ON user_sessions (token);

CREATE INDEX ix_user_sessions_user_id ON user_sessions (user_id);

CREATE TABLE organization_students (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	teacher_member_id UUID, 
	student_notes TEXT, 
	status VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_student UNIQUE (organization_id, user_id), 
	CONSTRAINT uq_organization_student_teacher_identity UNIQUE (id, teacher_member_id), 
	CONSTRAINT fk_student_teacher_same_studio FOREIGN KEY(organization_id, teacher_member_id) REFERENCES organization_members (organization_id, id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_organization_students_organization_id ON organization_students (organization_id);

CREATE INDEX ix_organization_students_teacher_member_id ON organization_students (teacher_member_id);

CREATE INDEX ix_organization_students_user_id ON organization_students (user_id);

CREATE TABLE payments (
	id UUID NOT NULL, 
	order_id UUID NOT NULL, 
	amount NUMERIC(10, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	payment_provider VARCHAR(50) NOT NULL, 
	provider_order_id VARCHAR(255), 
	provider_payment_id VARCHAR(255), 
	provider_signature VARCHAR(512), 
	status VARCHAR(50) NOT NULL, 
	idempotency_key VARCHAR(255), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(order_id) REFERENCES orders (id) ON DELETE CASCADE, 
	UNIQUE (idempotency_key)
);

CREATE INDEX ix_payments_order_id ON payments (order_id);

CREATE INDEX ix_payments_provider_order_id ON payments (provider_order_id);

CREATE INDEX ix_payments_provider_payment_id ON payments (provider_payment_id);

CREATE INDEX ix_payments_status ON payments (status);

CREATE TABLE sessions (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	class_type_id UUID NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	slug VARCHAR(255) NOT NULL, 
	short_description VARCHAR(500), 
	full_description TEXT, 
	session_type VARCHAR(50) NOT NULL, 
	capacity INTEGER NOT NULL, 
	min_age INTEGER, 
	max_age INTEGER, 
	skill_level VARCHAR(50) NOT NULL, 
	duration_minutes INTEGER NOT NULL, 
	language VARCHAR(50) NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	is_public BOOLEAN NOT NULL, 
	meeting_url VARCHAR(1024), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	deleted_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(class_type_id) REFERENCES class_types (id) ON DELETE CASCADE
);

CREATE INDEX ix_sessions_class_type_id ON sessions (class_type_id);

CREATE INDEX ix_sessions_organization_id ON sessions (organization_id);

CREATE INDEX ix_sessions_slug ON sessions (slug);

CREATE TABLE class_occurrences (
	id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	instructor_id UUID, 
	scheduled_start_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	scheduled_end_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	actual_start_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	actual_end_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	meeting_url VARCHAR(1024), 
	cancellation_reason TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(session_id) REFERENCES sessions (id) ON DELETE CASCADE, 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(instructor_id) REFERENCES organization_members (id) ON DELETE SET NULL
);

CREATE INDEX ix_class_occurrences_actual_start_at ON class_occurrences (actual_start_at);

CREATE INDEX ix_class_occurrences_instructor_id ON class_occurrences (instructor_id);

CREATE INDEX ix_class_occurrences_org_time ON class_occurrences (organization_id, actual_start_at);

CREATE INDEX ix_class_occurrences_organization_id ON class_occurrences (organization_id);

CREATE INDEX ix_class_occurrences_session_id ON class_occurrences (session_id);

CREATE INDEX ix_class_occurrences_status ON class_occurrences (status);

CREATE TABLE order_items (
	id UUID NOT NULL, 
	order_id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	unit_price NUMERIC(10, 2) NOT NULL, 
	quantity INTEGER NOT NULL, 
	subtotal NUMERIC(10, 2) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(order_id) REFERENCES orders (id) ON DELETE CASCADE, 
	FOREIGN KEY(session_id) REFERENCES sessions (id)
);

CREATE INDEX ix_order_items_order_id ON order_items (order_id);

CREATE INDEX ix_order_items_session_id ON order_items (session_id);

CREATE TABLE session_enrollments (
	id UUID NOT NULL, 
	organization_id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	order_id UUID, 
	status VARCHAR(50) NOT NULL, 
	valid_from TIMESTAMP WITH TIME ZONE NOT NULL, 
	valid_until TIMESTAMP WITH TIME ZONE, 
	total_sessions INTEGER, 
	sessions_attended INTEGER NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(session_id) REFERENCES sessions (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	UNIQUE (order_id), 
	FOREIGN KEY(order_id) REFERENCES orders (id) ON DELETE SET NULL
);

CREATE INDEX ix_session_enrollments_organization_id ON session_enrollments (organization_id);

CREATE INDEX ix_session_enrollments_session_id ON session_enrollments (session_id);

CREATE INDEX ix_session_enrollments_status ON session_enrollments (status);

CREATE INDEX ix_session_enrollments_user_id ON session_enrollments (user_id);

CREATE TABLE session_instructors (
	id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	member_id UUID NOT NULL, 
	role VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(session_id) REFERENCES sessions (id) ON DELETE CASCADE, 
	FOREIGN KEY(member_id) REFERENCES organization_members (id) ON DELETE CASCADE
);

CREATE INDEX ix_session_instructors_member_id ON session_instructors (member_id);

CREATE INDEX ix_session_instructors_session_id ON session_instructors (session_id);

CREATE TABLE session_pricing (
	id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	pricing_type VARCHAR(50) NOT NULL, 
	price NUMERIC(10, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	total_classes INTEGER, 
	validity_days INTEGER, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (session_id), 
	FOREIGN KEY(session_id) REFERENCES sessions (id) ON DELETE CASCADE
);

CREATE TABLE session_requirements (
	id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	prerequisites TEXT, 
	required_equipment TEXT, 
	preparation_instructions TEXT, 
	additional_notes TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (session_id), 
	FOREIGN KEY(session_id) REFERENCES sessions (id) ON DELETE CASCADE
);

CREATE TABLE session_schedule_rules (
	id UUID NOT NULL, 
	session_id UUID NOT NULL, 
	day_of_week INTEGER NOT NULL, 
	start_time TIME WITHOUT TIME ZONE NOT NULL, 
	end_time TIME WITHOUT TIME ZONE NOT NULL, 
	timezone VARCHAR(100) NOT NULL, 
	effective_start_date DATE NOT NULL, 
	effective_end_date DATE, 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(session_id) REFERENCES sessions (id) ON DELETE CASCADE
);

CREATE INDEX ix_session_schedule_rules_session_id ON session_schedule_rules (session_id);

CREATE TABLE attendance_records (
	id UUID NOT NULL, 
	class_occurrence_id UUID NOT NULL, 
	session_enrollment_id UUID NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	marked_by_user_id UUID, 
	marked_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_occurrence_enrollment_attendance UNIQUE (class_occurrence_id, session_enrollment_id), 
	FOREIGN KEY(class_occurrence_id) REFERENCES class_occurrences (id) ON DELETE CASCADE, 
	FOREIGN KEY(session_enrollment_id) REFERENCES session_enrollments (id) ON DELETE CASCADE, 
	FOREIGN KEY(marked_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX ix_attendance_records_class_occurrence_id ON attendance_records (class_occurrence_id);

CREATE INDEX ix_attendance_records_session_enrollment_id ON attendance_records (session_enrollment_id);

CREATE TABLE teacher_attendance_records (
	id UUID NOT NULL,
	class_occurrence_id UUID NOT NULL,
	teacher_member_id UUID NOT NULL,
	status VARCHAR(50) NOT NULL,
	marked_by_user_id UUID,
	marked_at TIMESTAMP WITH TIME ZONE NOT NULL,
	notes TEXT,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL,
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
	PRIMARY KEY (id),
	CONSTRAINT uq_occurrence_teacher_attendance UNIQUE (class_occurrence_id, teacher_member_id),
	CONSTRAINT ck_teacher_attendance_status CHECK (status IN ('ATTENDED', 'ABSENT', 'EXCUSED')),
	FOREIGN KEY(class_occurrence_id) REFERENCES class_occurrences (id) ON DELETE CASCADE,
	FOREIGN KEY(teacher_member_id) REFERENCES organization_members (id) ON DELETE RESTRICT,
	FOREIGN KEY(marked_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX ix_teacher_attendance_records_occurrence_id ON teacher_attendance_records (class_occurrence_id);

CREATE INDEX ix_teacher_attendance_records_teacher_member_id ON teacher_attendance_records (teacher_member_id);

CREATE TABLE student_session_queries (
	id UUID NOT NULL,
	organization_id UUID NOT NULL,
	organization_student_id UUID NOT NULL,
	session_enrollment_id UUID NOT NULL,
	class_occurrence_id UUID,
	assigned_teacher_member_id UUID NOT NULL,
	request_type VARCHAR(20) NOT NULL,
	status VARCHAR(20) NOT NULL,
	message TEXT NOT NULL,
	teacher_response TEXT,
	resolved_by_user_id UUID,
	resolved_at TIMESTAMP WITH TIME ZONE,
	withdrawn_at TIMESTAMP WITH TIME ZONE,
	created_at TIMESTAMP WITH TIME ZONE NOT NULL,
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
	PRIMARY KEY (id),
	CONSTRAINT ck_student_session_query_type CHECK (request_type IN ('POSTPONE', 'EXTEND')),
	CONSTRAINT ck_student_session_query_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
	CONSTRAINT ck_student_session_query_target CHECK (
		(request_type = 'POSTPONE' AND class_occurrence_id IS NOT NULL)
		OR request_type = 'EXTEND'
	),
	CONSTRAINT ck_student_session_query_resolution CHECK (
		(status IN ('PENDING', 'WITHDRAWN') AND resolved_at IS NULL AND resolved_by_user_id IS NULL)
		OR (status IN ('APPROVED', 'REJECTED') AND resolved_at IS NOT NULL AND resolved_by_user_id IS NOT NULL)
	),
	CONSTRAINT ck_student_session_query_withdrawal CHECK (
		(status = 'WITHDRAWN' AND withdrawn_at IS NOT NULL)
		OR (status <> 'WITHDRAWN' AND withdrawn_at IS NULL)
	),
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
	FOREIGN KEY(organization_student_id) REFERENCES organization_students (id) ON DELETE RESTRICT,
	FOREIGN KEY(session_enrollment_id) REFERENCES session_enrollments (id) ON DELETE RESTRICT,
	FOREIGN KEY(class_occurrence_id) REFERENCES class_occurrences (id) ON DELETE RESTRICT,
	FOREIGN KEY(organization_student_id, assigned_teacher_member_id)
		REFERENCES organization_students (id, teacher_member_id) ON DELETE RESTRICT,
	FOREIGN KEY(resolved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX ix_student_session_queries_teacher_status_created
	ON student_session_queries (assigned_teacher_member_id, status, created_at DESC);

CREATE INDEX ix_student_session_queries_student_created
	ON student_session_queries (organization_student_id, created_at DESC);

CREATE TABLE class_occurrence_changes (
	id UUID NOT NULL, 
	class_occurrence_id UUID NOT NULL, 
	changed_by_user_id UUID, 
	change_type VARCHAR(50) NOT NULL, 
	previous_start_at TIMESTAMP WITH TIME ZONE, 
	new_start_at TIMESTAMP WITH TIME ZONE, 
	reason TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(class_occurrence_id) REFERENCES class_occurrences (id) ON DELETE CASCADE, 
	FOREIGN KEY(changed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX ix_class_occurrence_changes_class_occurrence_id ON class_occurrence_changes (class_occurrence_id);
