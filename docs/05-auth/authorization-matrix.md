# ProgressRooms Role & Authorization Matrix

## 1. System Roles
- **SUPER_ADMIN**: ProgressRooms platform operator.
- **OWNER**: Creator/owner of an Organization.
- **ADMIN**: Administrative staff within an Organization.
- **INSTRUCTOR**: Teacher assigned to conduct classes.
- **STUDENT**: Enrolled learner.

## 2. Permission Matrix

| Action | Super Admin | Org Owner | Org Admin | Instructor | Student | Public |
|--------|-------------|-----------|-----------|------------|---------|--------|
| View Public Teacher Page | Yes | Yes | Yes | Yes | Yes | Yes |
| View Public Session Details | Yes | Yes | Yes | Yes | Yes | Yes |
| Purchase / Enroll in Session | - | - | - | - | Yes | - |
| View Own Student Dashboard | - | - | - | - | Yes | - |
| Access Meeting URL (15m before) | - | Yes | Yes | Yes (Assigned) | Yes (Enrolled) | No |
| Manage Organization Settings | Yes | Yes | No | No | No | No |
| Manage Plan & Billing | Yes | Yes | No | No | No | No |
| Add / Remove Instructors | Yes | Yes | Yes | No | No | No |
| Create / Edit Sessions | Yes | Yes | Yes | No | No | No |
| View Org Calendar | Yes | Yes | Yes | Assigned Only | No | No |
| Mark Class Attendance | Yes | Yes | Yes | Assigned Only | No | No |
| Edit Public Website & Templates | Yes | Yes | Yes | No | No | No |
| View Platform Analytics | Yes | No | No | No | No | No |
| Suspend Organization | Yes | No | No | No | No | No |
