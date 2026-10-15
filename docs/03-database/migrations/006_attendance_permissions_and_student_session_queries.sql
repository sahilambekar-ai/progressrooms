-- Migration 006: attendance audiences and student session queries.
-- Apply through Alembic in production. This SQL is the PostgreSQL reference for
-- the migration's upgrade; the downgrade drops the new tables and constraint.

ALTER TABLE organization_students
    ADD CONSTRAINT uq_organization_student_teacher_identity
    UNIQUE (id, teacher_member_id);

CREATE TABLE teacher_attendance_records (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    class_occurrence_id UUID NOT NULL REFERENCES class_occurrences(id) ON DELETE CASCADE,
    teacher_member_id UUID NOT NULL REFERENCES organization_members(id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL,
    marked_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    marked_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT uq_occurrence_teacher_attendance UNIQUE (class_occurrence_id, teacher_member_id),
    CONSTRAINT ck_teacher_attendance_status
        CHECK (status IN ('ATTENDED', 'ABSENT', 'EXCUSED'))
);

CREATE INDEX ix_teacher_attendance_records_occurrence_id
    ON teacher_attendance_records (class_occurrence_id);
CREATE INDEX ix_teacher_attendance_records_teacher_member_id
    ON teacher_attendance_records (teacher_member_id);

CREATE TABLE student_session_queries (
    id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    organization_student_id UUID NOT NULL REFERENCES organization_students(id) ON DELETE RESTRICT,
    session_enrollment_id UUID NOT NULL REFERENCES session_enrollments(id) ON DELETE RESTRICT,
    class_occurrence_id UUID REFERENCES class_occurrences(id) ON DELETE RESTRICT,
    assigned_teacher_member_id UUID NOT NULL,
    request_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    message TEXT NOT NULL,
    teacher_response TEXT,
    resolved_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    withdrawn_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT ck_student_session_query_type
        CHECK (request_type IN ('POSTPONE', 'EXTEND')),
    CONSTRAINT ck_student_session_query_status
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')),
    CONSTRAINT ck_student_session_query_target
        CHECK ((request_type = 'POSTPONE' AND class_occurrence_id IS NOT NULL) OR request_type = 'EXTEND'),
    CONSTRAINT ck_student_session_query_resolution
        CHECK (
            (status IN ('PENDING', 'WITHDRAWN') AND resolved_at IS NULL AND resolved_by_user_id IS NULL)
            OR (status IN ('APPROVED', 'REJECTED') AND resolved_at IS NOT NULL AND resolved_by_user_id IS NOT NULL)
        ),
    CONSTRAINT ck_student_session_query_withdrawal
        CHECK (
            (status = 'WITHDRAWN' AND withdrawn_at IS NOT NULL)
            OR (status <> 'WITHDRAWN' AND withdrawn_at IS NULL)
        ),
    CONSTRAINT fk_student_session_query_assigned_teacher
        FOREIGN KEY (organization_student_id, assigned_teacher_member_id)
        REFERENCES organization_students (id, teacher_member_id) ON DELETE RESTRICT
);

CREATE INDEX ix_student_session_queries_teacher_status_created
    ON student_session_queries (assigned_teacher_member_id, status, created_at DESC);
CREATE INDEX ix_student_session_queries_student_created
    ON student_session_queries (organization_student_id, created_at DESC);

-- The service must additionally validate same-organization and same-session
-- relationships: PostgreSQL cannot infer these through independent UUID FKs.
