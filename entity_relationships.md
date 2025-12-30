# Medical Lab System - Entity Relationship Diagram

## ERD Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER MANAGEMENT                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐         ┌─────────┐    │
│  │  Admin  │◄────────┤  Owner  │────────►┤  Staff  │◄────────┤  Device │    │
│  │         │         │         │         │         │         │         │    │
│  └─────────┘         └─────────┘         └─────────┘         └─────────┘    │
│           │                 │                     │                         │
│           │                 │                     │                         │
│           │                 │                     │                         │
│           ▼                 ▼                     ▼                         │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐                        │
│  │ Patient │◄────────┤  Order  │◄────────┤  Doctor │                        │
│  │         │         │         │         │         │                        │
│  └─────────┘         └─────────┘         └─────────┘                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                            ORDER PROCESSING                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────┐         ┌─────────────┐         ┌─────────┐         ┌─────────┐ │
│  │  Order  │────────►│ OrderDetails │────────►│  Test   │────────►│  Result │ │
│  │         │         │             │         │         │         │         │ │
│  └─────────┘         └─────────────┘         └─────────┘         └─────────┘ │
│           │                 │                     │                         │
│           │                 │                     │                         │
│           │                 │                     │                         │
│           ▼                 ▼                     ▼                         │
│  ┌─────────┐         ┌─────────────┐         ┌─────────────┐                │
│  │ Invoice │         │   Device    │         │ TestComponent │                │
│  │         │         │             │         │               │                │
│  └─────────┘         └─────────────┘         └─────────────┘                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           SYSTEM MANAGEMENT                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐            │
│  │ Notification│         │  Feedback   │         │  AuditLog   │            │
│  │             │         │             │         │             │            │
│  └─────────────┘         └─────────────┘         └─────────────┘            │
│                                                                             │
│  ┌─────────────┐                                                            │
│  │  Inventory  │                                                            │
│  │             │                                                            │
│  └─────────────┘                                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Detailed Relationships

### User Hierarchy
```
Admin (1) ────► Owner (N)
Owner (1) ────► Staff (N)
Owner (1) ────► Device (N)
Staff (1) ────► Device (1) [Assignment]
```

### Order Flow
```
Patient (1) ────► Order (N)
Doctor (1) ────► Order (N)
Order (1) ────► OrderDetails (N)
OrderDetails (N) ────► Test (1)
OrderDetails (1) ────► Result (1)
Order (1) ────► Invoice (1)
```

### Test Structure
```
Test (1) ────► TestComponent (N)
TestComponent (1) ────► ResultComponent (1)
Result (1) ────► ResultComponent (N)
```

### Lab Management
```
Owner (1) ────► Test (N)
Owner (1) ────► Order (N)
Owner (1) ────► Inventory (N)
Owner (1) ────► Invoice (N)
Owner (1) ────► AuditLog (N)
```

### Staff Assignments
```
Staff (1) ────► OrderDetails (N) [Processing]
Staff (1) ────► Result (N) [Uploading]
Staff (1) ────► Invoice (N) [Payment Recording]
Staff (1) ────► AuditLog (N) [Activity Logging]
```

### Communication
```
[Any User] ────► Notification (N) [Sending/Receiving]
[Any User] ────► Feedback (N) [Providing]
Staff (1) ────► Feedback (N) [Responding]
```

## Cardinality Legend

- **(1)** = One record
- **(N)** = Many records
- **►** = One-to-Many relationship
- **◄** = Many-to-One relationship
- **[Text]** = Relationship description

## Key Constraints

1. **Username Uniqueness**: All user types share unique username space
2. **Lab Isolation**: Owner acts as data partition boundary
3. **Staff Authorization**: Only assigned staff can process specific tests
4. **Device Assignment**: Devices can be assigned to only one staff member
5. **Order Integrity**: Orders must belong to registered patients
6. **Result Authorization**: Results can only be uploaded by assigned staff
7. **Subscription Control**: Owners must have active subscriptions
8. **Audit Trail**: All staff actions are logged with lab context

## Polymorphic Relationships

- **Notifications**: sender/receiver can reference any user type
- **Feedback**: user/target can reference different model types
- **Orders**: requested_by can be Patient or Doctor
- **Audit Logs**: record_id can reference any model type

## Self-Referencing Relationships

- **Notifications**: Support conversation threading (parent/child messages)
- **Feedback**: Can reference other feedback for follow-ups