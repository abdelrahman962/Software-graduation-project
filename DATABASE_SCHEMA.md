# Medical Lab System - Database Schema Documentation

## Overview
This document describes all database tables (MongoDB collections) and their relationships in the Medical Lab System.

---

## Tables (Collections)

### 1. **Admin**
Primary system administrators with full access.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `username`: String (unique, lowercase, required)
- `password`: String (bcrypt hashed, required)
- `email`: String (unique, required)
- `full_name`: Object
  - `first`: String (required)
  - `middle`: String
  - `last`: String (required)
- `role`: String (default: 'admin')
- `created_at`: Date
- `last_login`: Date

**Relationships:**
- Has many `Owner` (One-to-Many via `admin_id`)

---

### 2. **Owner** (Lab Owner)
Represents laboratory owners who manage lab branches.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `full_name`: Object
  - `first`: String (required)
  - `middle`: String
  - `last`: String (required)
- `identity_number`: String (unique, required)
- `phone_number`: String (required)
- `email`: String (unique, required)
- `username`: String (unique, lowercase, required)
- `password`: String (bcrypt hashed, required)
- `lab_name`: String
- `address`: addressSchema (embedded)
- `subscriptionFee`: Number (default: 0)
- `subscription_end`: Date
- `is_active`: Boolean (default: true)
- `admin_id`: ObjectId → `Admin` (Many-to-One)
- `created_at`: Date
- `last_login`: Date

**Relationships:**
- Belongs to `Admin` (Many-to-One via `admin_id`)
- Has many `Staff` (One-to-Many)
- Has many `Device` (One-to-Many)
- Has many `Test` (One-to-Many)
- Has many `Order` (One-to-Many)
- Has many `Inventory` (One-to-Many)
- Has many `Invoice` (One-to-Many)
- Has many `AuditLog` (One-to-Many)
- Receives many `Notification` (Polymorphic)

---

### 3. **Staff**
Lab employees who perform tests and manage operations.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `full_name`: Object
  - `first`: String (required)
  - `middle`: String
  - `last`: String (required)
- `identity_number`: String (unique, required)
- `birthday`: Date (required)
- `gender`: String (enum: Male/Female/Other, required)
- `social_status`: String (enum: Single/Married/Divorced/Widowed)
- `phone_number`: String (required)
- `address`: addressSchema (embedded)
- `qualification`: String
- `profession_license`: String
- `employee_number`: String (unique)
- `bank_iban`: String
- `salary`: Number (default: 0)
- `employee_evaluation`: String
- `email`: String (unique, required)
- `username`: String (unique, lowercase, required)
- `password`: String (bcrypt hashed, required)
- `date_hired`: Date (default: now)
- `last_login`: Date
- `owner_id`: ObjectId → `LabOwner` (Many-to-One, required)
- `login_history`: Array of Dates

**Relationships:**
- Belongs to `Owner` (Many-to-One via `owner_id`)
- Has many `Patient` (One-to-Many via `created_by_staff`)
- Has many `Device` (One-to-Many via `staff_id`)
- Has many `OrderDetails` (One-to-Many via `staff_id`)
- Has many `Invoice` (One-to-Many via `paid_by`)
- Has many `AuditLog` (One-to-Many via `staff_id`)
- Sends/Receives many `Notification` (Polymorphic)
- Submits many `Feedback` (Polymorphic)

---

### 4. **Patient**
Patients who receive lab tests.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `full_name`: Object
  - `first`: String (required)
  - `middle`: String
  - `last`: String (required)
- `identity_number`: String (unique, required)
- `birthday`: Date (required)
- `gender`: String (enum: Male/Female/Other, required)
- `social_status`: String (enum: Single/Married/Divorced/Widowed)
- `phone_number`: String (required)
- `address`: addressSchema (embedded)
- `email`: String (unique, required)
- `username`: String (unique, lowercase, required)
- `password`: String (bcrypt hashed, required)
- `last_login`: Date
- `created_by_staff`: ObjectId → `Staff` (Many-to-One)
- `registration_date`: Date (default: now)

**Relationships:**
- Created by `Staff` (Many-to-One via `created_by_staff`)
- Has many `Order` (One-to-Many)
- Can request `Order` (Polymorphic via `requested_by`)
- Sends/Receives many `Notification` (Polymorphic)
- Submits many `Feedback` (Polymorphic)

---

### 5. **Doctor**
External doctors who can order tests for patients.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `full_name`: Object
  - `first`: String (required)
  - `middle`: String
  - `last`: String (required)
- `identity_number`: String (unique, required)
- `birthday`: Date (required)
- `gender`: String (enum: Male/Female/Other, required)
- `social_status`: String (enum: Single/Married/Divorced/Widowed)
- `phone_number`: String (required)
- `address`: addressSchema (embedded)
- `medical_license`: String
- `specialization`: String
- `email`: String (unique, required)
- `username`: String (unique, lowercase, required)
- `password`: String (bcrypt hashed, required)
- `last_login`: Date
- `registration_date`: Date (default: now)

**Relationships:**
- Has many `Order` (One-to-Many via `doctor_id`)
- Can request `Order` (Polymorphic via `requested_by`)
- Sends/Receives many `Notification` (Polymorphic)
- Submits many `Feedback` (Polymorphic)

---

### 6. **Order**
Lab test orders placed for patients.

**Note**: Orders are created manually by lab staff when patients visit the laboratory.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `patient_id`: ObjectId → `Patient` (Many-to-One, required)
- `address`: addressSchema (embedded)
- `temp_patient_info`: Object (temporary data before patient registration)
  - `full_name`: Object (first, middle, last)
  - `identity_number`: String
  - `email`: String
  - `phone_number`: String
  - `birthday`: Date
  - `gender`: String
  - `address`: String
- `requested_by`: ObjectId (Polymorphic via `requested_by_model`)
- `requested_by_model`: String (enum: Patient/Doctor)
- `doctor_id`: ObjectId → `Doctor` (Many-to-One)
- `order_date`: Date (default: now)
- `status`: String (enum: pending/processing/completed, default: pending)
- `remarks`: String
- `barcode`: String (unique, sparse)
- `owner_id`: ObjectId → `LabOwner` (Many-to-One, required)
- `is_patient_registered`: Boolean (default: false)
- `registration_token`: String (unique, sparse)
- `registration_token_expires`: Date
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Belongs to `Patient` (Many-to-One via `patient_id`)
- Belongs to `Owner` (Many-to-One via `owner_id`)
- Belongs to `Doctor` (Many-to-One via `doctor_id`, optional)
- Requested by `Patient` OR `Doctor` (Polymorphic via `requested_by/requested_by_model`)
- Has many `OrderDetails` (One-to-Many)
- Has one `Invoice` (One-to-One)

---

### 7. **OrderDetails**
Individual tests within an order with assignment and tracking.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `order_id`: ObjectId → `Orders` (Many-to-One)
- `test_id`: ObjectId → `TestManagement` (Many-to-One)
- `barcode`: String (unique, sparse)
- `device_id`: ObjectId → `Device` (Many-to-One)
- `staff_id`: ObjectId → `Staff` (Many-to-One)
- `assigned_at`: Date
- `sample_collected`: Boolean (default: false)
- `sample_collected_date`: Date
- `status`: String (enum: pending/assigned/urgent/collected/in_progress/completed, default: pending)
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Belongs to `Order` (Many-to-One via `order_id`)
- Belongs to `Test` (Many-to-One via `test_id`)
- Assigned to `Device` (Many-to-One via `device_id`)
- Assigned to `Staff` (Many-to-One via `staff_id`)
- Has one `Result` (One-to-One)

---

### 8. **Result**
Test results for completed order details.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `detail_id`: ObjectId → `OrderDetails` (One-to-One)
- `result_value`: String
- `units`: String
- `reference_range`: String
- `remarks`: String
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Belongs to `OrderDetails` (One-to-One via `detail_id`)

---

### 9. **Test** (TestManagement)
Available lab tests that can be ordered.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `test_code`: String (required)
- `test_name`: String (required)
- `sample_type`: String
- `tube_type`: String
- `is_active`: Boolean (default: true)
- `device_id`: ObjectId → `Device` (Many-to-One)
- `method`: String (enum: manual/device)
- `units`: String
- `reference_range`: String
- `price`: Number
- `owner_id`: ObjectId → `LabOwner` (Many-to-One, required)
- `turnaround_time`: String
- `collection_time`: String
- `reagent`: String
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Belongs to `Owner` (Many-to-One via `owner_id`)
- Performed on `Device` (Many-to-One via `device_id`)
- Appears in many `OrderDetails` (One-to-Many)
- Can be target of `Feedback` (Polymorphic)

---

### 10. **Device**
Laboratory equipment used for testing.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `name`: String
- `serial_number`: String (unique)
- `cleaning_reagent`: String
- `manufacturer`: String
- `status`: String (enum: active/inactive/maintenance, default: active)
- `staff_id`: ObjectId → `Staff` (Many-to-One)
- `capacity_of_sample`: Number
- `maintenance_schedule`: String (enum: daily/weekly/monthly)
- `owner_id`: ObjectId → `LabOwner` (Many-to-One)
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Belongs to `Owner` (Many-to-One via `owner_id`)
- Assigned to `Staff` (Many-to-One via `staff_id`)
- Used by many `Test` (One-to-Many)
- Assigned to many `OrderDetails` (One-to-Many)

---

### 11. **Invoice**
Payment invoices for orders.

**Note**: Invoices are created manually by lab staff when patients visit the laboratory and place orders.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `order_id`: ObjectId → `Orders` (One-to-One)
- `invoice_date`: Date (default: now)
- `subtotal`: Number
- `discount`: Number (default: 0)
- `total_amount`: Number
- `amount_paid`: Number (default: 0)
- `payment_status`: String (enum: pending/paid/partial, default: pending)
- `payment_method`: String (enum: cash/card/bank_transfer)
- `payment_date`: Date
- `paid_by`: ObjectId → `Staff` (Many-to-One)
- `remarks`: String
- `owner_id`: ObjectId → `LabOwner` (Many-to-One)

**Relationships:**
- Belongs to `Order` (One-to-One via `order_id`)
- Belongs to `Owner` (Many-to-One via `owner_id`)
- Recorded by `Staff` (Many-to-One via `paid_by`)

---

### 12. **Inventory** (StockInventory)
Lab inventory and stock management.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `name`: String
- `item_code`: String
- `cost`: Number
- `expiration_date`: Date
- `critical_level`: Number
- `count`: Number
- `balance`: Number
- `owner_id`: ObjectId → `LabOwner` (Many-to-One)

**Additional Collections:**
- **StockInput**: Tracks inventory additions
  - `item_id`: ObjectId → `StockInventory`
  - `input_value`: Number
  - `input_date`: Date
- **StockOutput**: Tracks inventory usage
  - `item_id`: ObjectId → `StockInventory`
  - `output_value`: Number
  - `out_date`: Date

**Relationships:**
- Belongs to `Owner` (Many-to-One via `owner_id`)
- Has many `StockInput` records (One-to-Many)
- Has many `StockOutput` records (One-to-Many)
- Can be target of `Notification` (inventory alerts)

---

### 13. **Notification**
System notifications for all user types.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `sender_id`: ObjectId (Polymorphic via `sender_model`)
- `sender_model`: String (enum: Admin/Owner/Doctor/Patient/Staff)
- `receiver_id`: ObjectId (Polymorphic via `receiver_model`)
- `receiver_model`: String (enum: Admin/Owner/Doctor/Patient/Staff, required)
- `type`: String (enum: subscription/system/maintenance/test_result/request/payment/inventory)
- `title`: String
- `message`: String
- `related_id`: ObjectId (generic reference)
- `is_read`: Boolean (default: false)
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Sent by ANY user type (Polymorphic via `sender_id/sender_model`)
- Received by ANY user type (Polymorphic via `receiver_id/receiver_model`)
- Can reference any entity via `related_id`

---

### 14. **AuditLog**
System audit trail for tracking actions.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `staff_id`: ObjectId → `Staff` (Many-to-One)
- `username`: String
- `action`: String
- `table_name`: String
- `record_id`: ObjectId (generic reference)
- `message`: String
- `timestamp`: Date (default: now)
- `owner_id`: ObjectId → `LabOwner` (Many-to-One)

**Relationships:**
- Belongs to `Staff` (Many-to-One via `staff_id`)
- Belongs to `Owner` (Many-to-One via `owner_id`)
- References any entity via `record_id`

---

### 15. **Feedback**
User feedback system for labs, tests, and services.

**Fields:**
- `_id`: ObjectId (Primary Key)
- `user_id`: ObjectId (Polymorphic via `user_model`, required)
- `user_model`: String (enum: Doctor/Patient/Staff/Owner, required)
- `target_type`: String (enum: system/lab/test/order/service, required)
- `target_id`: ObjectId (Polymorphic via `target_model`)
- `target_model`: String (enum: Owner/Test/Order/Service)
- `rating`: Number (1-5)
- `comment`: String
- `status`: String (enum: pending/reviewed/resolved)
- `created_at`: Date
- `updated_at`: Date

**Relationships:**
- Submitted by ANY user type (Polymorphic via `user_id/user_model`)
- Targets `Owner`/`Test`/`Order`/Service or system (Polymorphic via `target_id/target_model`)

---

### 16. **addressSchema** (Embedded Document)
Reusable address schema embedded in multiple collections.

**Fields:**
- `street`: String
- `city`: String
- `country`: String (default: 'Palestine')

**Used in:**
- Owner.address
- Staff.address
- Patient.address
- Doctor.address
- Order.address

---

## Relationship Summary

### One-to-One (1:1)
1. **Order ↔ Invoice** (order_id)
2. **OrderDetails ↔ Result** (detail_id)

### One-to-Many (1:N)

#### Admin Relationships
1. **Admin → Owner** (admin_id)

#### Owner (LabOwner) Relationships
2. **Owner → Staff** (owner_id)
3. **Owner → Device** (owner_id)
4. **Owner → Test** (owner_id)
5. **Owner → Order** (owner_id)
6. **Owner → Inventory** (owner_id)
7. **Owner → Invoice** (owner_id)
8. **Owner → AuditLog** (owner_id)

#### Staff Relationships
9. **Staff → Patient** (created_by_staff)
10. **Staff → Device** (staff_id - assigned devices)
11. **Staff → OrderDetails** (staff_id - assigned tests)
12. **Staff → Invoice** (paid_by - payment recorder)
13. **Staff → AuditLog** (staff_id - action performer)

#### Patient Relationships
14. **Patient → Order** (patient_id)

#### Doctor Relationships
15. **Doctor → Order** (doctor_id - optional)

#### Order Relationships
16. **Order → OrderDetails** (order_id)

#### OrderDetails Relationships
17. **OrderDetails ← Test** (test_id)
18. **OrderDetails ← Device** (device_id)

#### Device Relationships
19. **Device → Test** (device_id - tests using device)
20. **Device → OrderDetails** (device_id - assigned to test details)

#### Inventory Relationships
21. **Inventory → StockInput** (item_id)
22. **Inventory → StockOutput** (item_id)

### Polymorphic Relationships

#### Order Requested By (Patient OR Doctor)
- **Order.requested_by** → Patient OR Doctor
- **Order.requested_by_model** = 'Patient' | 'Doctor'

#### Notification System
- **Notification.sender_id** → Admin | Owner | Doctor | Patient | Staff
- **Notification.sender_model** = 'Admin' | 'Owner' | 'Doctor' | 'Patient' | 'Staff'
- **Notification.receiver_id** → Admin | Owner | Doctor | Patient | Staff
- **Notification.receiver_model** = 'Admin' | 'Owner' | 'Doctor' | 'Patient' | 'Staff'

#### Feedback System
- **Feedback.user_id** → Doctor | Patient | Staff | Owner
- **Feedback.user_model** = 'Doctor' | 'Patient' | 'Staff' | 'Owner'
- **Feedback.target_id** → Owner | Test | Order | Service
- **Feedback.target_model** = 'Owner' | 'Test' | 'Order' | 'Service'

### Many-to-Many
**None identified** - The system uses junction tables (OrderDetails) or direct references rather than many-to-many relationships.

---

## Entity Relationship Diagram (ERD) - Text Format

```
┌─────────────┐
│   Admin     │
└──────┬──────┘
       │ 1:N
       ▼
┌─────────────┐          ┌─────────────┐          ┌─────────────┐
│   Owner     │◄─────────┤  Inventory  │          │   Device    │
│ (LabOwner)  │  1:N     └─────────────┘          └──────┬──────┘
└──────┬──────┘                                           │
       │ 1:N                                              │ M:1
       │                                                  ▼
       │                    ┌─────────────┐          ┌─────────────┐
       │                    │    Staff    │◄─────────┤    Test     │
       │                    └──────┬──────┘   1:N    └──────┬──────┘
       │                           │ 1:N              M:1    │
       │                           ▼                         │
       │                    ┌─────────────┐                 │
       │                    │   Patient   │                 │
       │                    └──────┬──────┘                 │
       │                           │ 1:N                    │
       ▼                           ▼                        │
┌─────────────┐          ┌─────────────────┐              │
│    Order    │◄─────────┤  Doctor         │              │
└──────┬──────┘   1:N    └─────────────────┘              │
       │ 1:1                                               │
       ├──────────────────┐                                │
       │                  │ 1:N                            │
       ▼                  ▼                                │
┌─────────────┐    ┌──────────────────┐                   │
│   Invoice   │    │  OrderDetails    │◄──────────────────┘
└─────────────┘    └────────┬─────────┘      M:1
                            │ 1:1
                            ▼
                     ┌─────────────┐
                     │   Result    │
                     └─────────────┘

Polymorphic:
┌─────────────┐
│Notification │ ──► Any user type (sender/receiver)
└─────────────┘

┌─────────────┐
│  Feedback   │ ──► Any user type (submitter) → Owner/Test/Order (target)
└─────────────┘

┌─────────────┐
│  AuditLog   │ ──► Staff (actor) → Owner (lab context)
└─────────────┘
```

---

## Key Design Patterns

### 1. **Hierarchical User Structure**
- Admin manages Owners
- Owners manage Staff
- Staff creates Patients
- Doctors are independent but collaborate

### 2. **Polymorphic References**
- **refPath Pattern**: Used for flexible relationships where a field can reference multiple model types
  - Order.requested_by → Patient OR Doctor
  - Notification sender/receiver → Any user type
  - Feedback user/target → Multiple types

### 3. **Embedded Documents**
- **addressSchema**: Consistent address structure across all user types
- Embedded in: Owner, Staff, Patient, Doctor, Order

### 4. **Order Processing Workflow**
```
Patient visits laboratory in person
  ↓
Staff manually creates Order (patient info + requested tests)
  ↓
Staff manually creates Invoice (calculates total from test prices)
  ↓
Patient pays at lab counter (cash/card/bank transfer)
  ↓
Staff manually records payment in system
  ↓
Staff assigns OrderDetails to Devices + Staff
  ↓
Tests are performed and Results recorded
  ↓
Invoice marked as paid when payment received
```

### 5. **Username Uniqueness**
- All user types (Admin, Owner, Staff, Patient, Doctor) validate username uniqueness across ALL collections
- Prevents duplicate usernames system-wide

### 6. **Soft Reference Pattern**
- Some relationships use generic ObjectId without ref for flexibility
- Examples: AuditLog.record_id, Notification.related_id, Feedback.target_id

---

## Database Statistics

- **Total Collections**: 16 main collections (+ 2 stock tracking collections)
- **Total Relationships**: 40+ defined relationships
- **One-to-One**: 2 relationships
- **One-to-Many**: 22+ relationships
- **Polymorphic**: 4 polymorphic systems
- **Embedded Documents**: 1 reusable schema (addressSchema)

---

## Notes

1. **MongoDB ObjectId**: All IDs are MongoDB ObjectId type
2. **Timestamps**: Most collections use automatic `created_at` and `updated_at` timestamps
3. **Unique Constraints**: Multiple fields have unique indexes (username, email, identity_number, serial_number, etc.)
4. **Sparse Indexes**: Used for optional unique fields (barcode, registration_token) to allow null values
5. **Password Security**: All passwords are bcrypt hashed before storage
6. **Enum Validation**: Status fields use enum constraints for data integrity
7. **Default Values**: Many fields have sensible defaults (is_active: true, payment_status: 'pending', etc.)

---

**Generated**: 2024
**Last Updated**: Current session
**Database**: MongoDB with Mongoose ODM
