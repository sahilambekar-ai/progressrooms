# ProgressRooms Domain Model

## 1. Domain Entities Overview

ProgressRooms is an industry-agnostic multi-tenant operating system for businesses offering scheduled instruction.

```mermaid
classDiagram
    class User {
        +UUID id
        +String email
        +String phone
        +String full_name
        +Boolean is_superadmin
    }
    class Organization {
        +UUID id
        +String name
        +String slug
        +String timezone
        +String currency
        +String status
    }
    class OrganizationMember {
        +UUID id
        +UUID organization_id
        +UUID user_id
        +Role role (OWNER, ADMIN, INSTRUCTOR)
    }
    class Plan {
        +UUID id
        +String name
        +String slug
        +Decimal price
        +String billing_interval
    }
    class OrganizationSubscription {
        +UUID id
        +UUID organization_id
        +UUID plan_id
        +SubscriptionStatus status
        +DateTime starts_at
        +DateTime ends_at
    }
    class ClassType {
        +UUID id
        +UUID organization_id
        +String name
        +String description
    }
    class Session {
        +UUID id
        +UUID organization_id
        +UUID class_type_id
        +String name
        +String slug
        +SessionType type
        +PricingModel pricing_model
        +Decimal price
    }
    class ScheduleRule {
        +UUID id
        +UUID session_id
        +Int[] days_of_week
        +Time start_time
        +Time end_time
    }
    class ClassOccurrence {
        +UUID id
        +UUID session_id
        +UUID instructor_id
        +DateTime actual_start_at
        +DateTime actual_end_at
        +OccurrenceStatus status
    }
    class StudentEnrollment {
        +UUID id
        +UUID organization_id
        +UUID session_id
        +UUID user_id
        +EnrollmentStatus status
        +Int total_sessions
        +Int sessions_attended
    }
    class Order {
        +UUID id
        +UUID organization_id
        +UUID user_id
        +Decimal total_amount
        +OrderStatus status
    }
    class Payment {
        +UUID id
        +UUID order_id
        +String razorpay_payment_id
        +PaymentStatus status
    }

    User "1" --> "*" OrganizationMember
    Organization "1" --> "*" OrganizationMember
    Organization "1" --> "1" OrganizationSubscription
    Plan "1" --> "*" OrganizationSubscription
    Organization "1" --> "*" ClassType
    ClassType "1" --> "*" Session
    Session "1" --> "*" ScheduleRule
    Session "1" --> "*" ClassOccurrence
    Session "1" --> "*" StudentEnrollment
    User "1" --> "*" StudentEnrollment
    Order "1" --> "*" Payment
    Order "1" --> "1" StudentEnrollment
```

## 2. Multi-Tenant Hierarchy
1. **Platform**: Governed by platform superadmins.
2. **Organization**: Multi-tenant boundary. Represents an individual teacher business or a multi-teacher studio. Every organization has an Owner and optional Admins/Instructors.
3. **Session & Classes**: Group classes, 1-on-1 sessions, workshops, and courses.
4. **Occurrences**: Concrete, scheduled class instances derived from recurrence rules.
5. **Students & Commerce**: Students enroll and make payments via Razorpay. Access is tracked via time-windows (monthly) or session credits (package).
