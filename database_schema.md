# Medical Lab System Database Schema

## Overview
This document describes the complete database schema for the Medical Lab System, including all tables (models), their fields, and relationships.

## Tables/Models Summary

| Table | Description | Key Relationships |
|-------|-------------|-------------------|
| [Admin](#admin) | System administrators | Manages Owners |
| [Owner](#owner) | Lab owners/managers | Owns Staff, Tests, Devices, Orders |
| [Staff](#staff) | Lab technicians | Assigned to Devices, Processes Orders |
| [Patient](#patient) | Test recipients | Places Orders, Receives Results |
| [Doctor](#doctor) | Referring physicians | Orders tests for patients |
| [Order](#order) | Test orders | Contains OrderDetails |
| [OrderDetails](#orderdetails) | Individual test items | Links Orders to Tests |
| [Test](#test) | Available tests | Has TestComponents |
| [TestComponent](#testcomponent) | Test sub-components | Belongs to Tests |
| [Result](#result) | Test results | Has ResultComponents |
| [ResultComponent](#resultcomponent) | Component results | Belongs to Results |
| [Device](#device) | Lab equipment | Assigned to Staff |
| [Inventory](#inventory) | Stock management | Owned by Labs |
| [Invoice](#invoice) | Billing records | Linked to Orders |
| [Notification](#notification) | System messages | User communications |
| [Feedback](#feedback) | User feedback | System improvement |
| [AuditLog](#auditlog) | Activity tracking | System monitoring |

---

## User Management Tables

### Admin
**Collection:** `admins`

System administrators who manage lab owners and system-wide operations.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `full_name.first` | String | Yes | First name |
| `full_name.middle` | String | No | Middle name |
| `full_name.last` | String | Yes | Last name |
| `identity_number` | String | Yes | Unique ID number |
| `birthday` | Date | No | Date of birth |
| `gender` | Enum | No | Male/Female/Other |
| `phone_number` | String | No | Contact number |
| `admin_id` | String | Yes | Unique admin identifier |
| `email` | String | Yes | Unique email address |
| `username` | String | Yes | Unique login username |
| `password` | String | Yes | Hashed password |

**Relationships:**
- 1:N → Owner (admin_id)

---

### Owner
**Collection:** `labowners`

Lab owners who manage their medical laboratories.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `subscriptionFee` | Number | No | Monthly subscription fee |
| `subscription_period_months` | Number | No | Subscription duration |
| `lab_name` | String | Yes | Laboratory name |
| `lab_license_number` | String | No | Lab license |
| `owner_id` | String | No | Unique owner identifier |
| `name.first` | String | Yes | First name |
| `name.middle` | String | No | Middle name |
| `name.last` | String | Yes | Last name |
| `identity_number` | String | Yes | Unique ID number |
| `birthday` | Date | Yes | Date of birth |
| `gender` | Enum | Yes | Male/Female/Other |
| `social_status` | Enum | No | Single/Married/Divorced/Widowed |
| `phone_number` | String | Yes | Contact number |
| `address` | AddressSchema | No | Address object |
| `qualification` | String | No | Professional qualification |
| `profession_license` | String | No | License number |
| `bank_iban` | String | No | Bank account |
| `email` | String | Yes | Unique email |
| `username` | String | Cond | Unique login username |
| `password` | String | Cond | Hashed password |
| `date_subscription` | Date | Auto | Subscription start date |
| `admin_id` | ObjectId → Admin | Yes | Reference to admin |
| `subscription_end` | Date | No | Subscription expiry |
| `is_active` | Boolean | No | Lab active status |
| `status` | Enum | No | pending/approved/rejected |
| `rejection_reason` | String | No | Rejection explanation |
| `temp_credentials` | Object | No | Temporary login details |

**Relationships:**
- N:1 ← Admin (admin_id)
- 1:N → Staff (owner_id)
- 1:N → Test (owner_id)
- 1:N → Device (owner_id)
- 1:N → Order (owner_id)
- 1:N → Inventory (owner_id)
- 1:N → Invoice (owner_id)
- 1:N → AuditLog (owner_id)

---

### Staff
**Collection:** `staffs`

Laboratory technicians and staff members.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `full_name.first` | String | Yes | First name |
| `full_name.middle` | String | No | Middle name |
| `full_name.last` | String | Yes | Last name |
| `identity_number` | String | Yes | Unique ID number |
| `birthday` | Date | Yes | Date of birth |
| `gender` | Enum | Yes | Male/Female/Other |
| `social_status` | Enum | No | Single/Married/Divorced/Widowed |
| `phone_number` | String | Yes | Contact number |
| `address` | AddressSchema | No | Address object |
| `qualification` | String | No | Professional qualification |
| `profession_license` | String | No | License number |
| `employee_number` | String | Yes | Unique employee ID |
| `bank_iban` | String | No | Bank account |
| `salary` | Number | No | Monthly salary |
| `employee_evaluation` | String | No | Performance review |
| `email` | String | Yes | Unique email |
| `username` | String | Yes | Unique login username |
| `password` | String | Yes | Hashed password |
| `date_hired` | Date | Auto | Employment start date |
| `last_login` | Date | No | Last login timestamp |
| `owner_id` | ObjectId → Owner | Yes | Reference to lab owner |
| `login_history` | [Date] | No | Login timestamps |

**Relationships:**
- N:1 ← Owner (owner_id)
- 1:N → OrderDetails (staff_id)
- 1:N → Result (staff_id)
- 1:N → Invoice (paid_by)
- 1:N → AuditLog (staff_id)
- 1:N → Feedback (responded_by)
- 1:1 → Device (staff_id)

---

### Patient
**Collection:** `patients`

Patients who receive medical tests.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `full_name.first` | String | Yes | First name |
| `full_name.middle` | String | No | Middle name |
| `full_name.last` | String | Yes | Last name |
| `identity_number` | String | Yes | Unique ID number |
| `birthday` | Date | No | Date of birth |
| `gender` | Enum | No | Male/Female/Other |
| `social_status` | Enum | No | Single/Married/Divorced/Widowed |
| `phone_number` | String | No | Contact number |
| `address` | AddressSchema | No | Address object |
| `patient_id` | String | Yes | Unique patient identifier |
| `insurance_provider` | String | No | Insurance company |
| `insurance_number` | String | No | Insurance policy number |
| `notes` | String | No | Medical notes |
| `email` | String | Yes | Unique email |
| `username` | String | No | Login username |
| `password` | String | Yes | Hashed password |
| `created_by_staff` | ObjectId → Staff | No | Staff who registered patient |
| `last_login` | Date | No | Last login timestamp |

**Relationships:**
- N:1 ← Staff (created_by_staff)
- 1:N → Order (patient_id)
- 1:N → Notification (receiver_id)

---

### Doctor
**Collection:** `doctors`

Medical doctors who refer patients for tests.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `doctor_id` | Number | Yes | Unique doctor identifier |
| `name.first` | String | Yes | First name |
| `name.middle` | String | No | Middle name |
| `name.last` | String | Yes | Last name |
| `identity_number` | String | Yes | Unique ID number |
| `birthday` | Date | Yes | Date of birth |
| `gender` | Enum | Yes | Male/Female/Other |
| `phone_number` | String | Yes | Contact number |
| `email` | String | Yes | Unique email |
| `username` | String | Yes | Unique login username |
| `password` | String | Yes | Hashed password |
| `specialty` | String | No | Medical specialty |
| `license_number` | String | No | Medical license |
| `years_of_experience` | Number | No | Years of experience |

**Relationships:**
- 1:N → Order (doctor_id)
- 1:N → Notification (receiver_id)

---

## Order Management Tables

### Order
**Collection:** `orders`

Main test orders placed by patients or doctors.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `patient_id` | ObjectId → Patient | Yes | Reference to patient |
| `address` | AddressSchema | No | Order delivery address |
| `temp_patient_info` | Object | No | Temporary patient data |
| `requested_by` | ObjectId | No | Who requested the order |
| `requested_by_model` | Enum | No | Patient/Doctor |
| `doctor_id` | ObjectId → Doctor | No | Referring doctor |
| `order_date` | Date | Auto | Order creation date |
| `status` | Enum | No | pending/processing/completed |
| `remarks` | String | No | Order notes |
| `owner_id` | ObjectId → Owner | Yes | Lab owner reference |
| `is_patient_registered` | Boolean | No | Patient registration status |
| `registration_token` | String | No | Account registration token |
| `registration_token_expires` | Date | No | Token expiry |

**Relationships:**
- N:1 ← Patient (patient_id)
- N:1 ← Doctor (doctor_id)
- N:1 ← Owner (owner_id)
- 1:N → OrderDetails (order_id)
- 1:N → Invoice (order_id)

---

### OrderDetails
**Collection:** `orderdetails`

Individual test items within orders.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `order_id` | ObjectId → Order | Yes | Reference to parent order |
| `test_id` | ObjectId → Test | Yes | Reference to test |
| `device_id` | ObjectId → Device | No | Assigned device |
| `staff_id` | ObjectId → Staff | No | Assigned staff |
| `assigned_at` | Date | No | Assignment timestamp |
| `sample_collected` | Boolean | No | Sample collection status |
| `sample_collected_date` | Date | No | Collection timestamp |
| `status` | Enum | No | pending/assigned/collected/in_progress/completed |

**Relationships:**
- N:1 ← Order (order_id)
- N:1 ← Test (test_id)
- N:1 ← Device (device_id)
- N:1 ← Staff (staff_id)
- 1:1 → Result (detail_id)

---

## Test Management Tables

### Test
**Collection:** `testmanagements`

Available medical tests in the laboratory.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `test_code` | String | Yes | Unique test code |
| `test_name` | String | Yes | Test name |
| `sample_type` | String | No | Type of sample required |
| `tube_type` | String | No | Tube/container type |
| `is_active` | Boolean | No | Test availability |
| `device_id` | ObjectId → Device | No | Required device |
| `method` | String | No | Testing method |
| `units` | String | No | Result units |
| `reference_range` | String | No | Normal reference range |
| `price` | Number | No | Test price |
| `owner_id` | ObjectId → Owner | Yes | Lab owner reference |
| `turnaround_time` | Number | No | Expected completion time (hours) |
| `collection_time` | String | No | Sample collection time |
| `reagent` | String | No | Required reagents |

**Relationships:**
- N:1 ← Owner (owner_id)
- N:1 ← Device (device_id)
- 1:N → TestComponent (test_id)
- 1:N → OrderDetails (test_id)
- 1:N → Invoice.items (test_id)

---

### TestComponent
**Collection:** `testcomponents`

Sub-components of complex tests.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `test_id` | ObjectId → Test | Yes | Parent test reference |
| `component_name` | String | Yes | Component name |
| `component_code` | String | No | Component code |
| `units` | String | No | Component units |
| `reference_range` | String | No | Component reference range |
| `min_value` | Number | No | Minimum normal value |
| `max_value` | Number | No | Maximum normal value |
| `display_order` | Number | No | Display sequence |
| `is_active` | Boolean | No | Component availability |
| `description` | String | No | Component description |

**Relationships:**
- N:1 ← Test (test_id)
- 1:1 → ResultComponent (component_id)

---

## Result Management Tables

### Result
**Collection:** `results`

Test results for completed orders.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `detail_id` | ObjectId → OrderDetails | Yes | Reference to order detail |
| `result_value` | String | No | Single result value |
| `units` | String | No | Result units |
| `reference_range` | String | No | Reference range |
| `remarks` | String | No | Result notes |
| `has_components` | Boolean | No | Multiple components flag |
| `is_abnormal` | Boolean | No | Abnormal result flag |
| `abnormal_components_count` | Number | No | Count of abnormal components |
| `staff_id` | ObjectId → Staff | No | Staff who uploaded result |

**Relationships:**
- 1:1 ← OrderDetails (detail_id)
- N:1 ← Staff (staff_id)
- 1:N → ResultComponent (result_id)

---

### ResultComponent
**Collection:** `resultcomponents`

Individual component results for complex tests.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `result_id` | ObjectId → Result | Yes | Parent result reference |
| `component_id` | ObjectId → TestComponent | Yes | Test component reference |
| `component_name` | String | Yes | Component name |
| `component_value` | String | Yes | Result value |
| `units` | String | No | Component units |
| `reference_range` | String | No | Component reference range |
| `is_abnormal` | Boolean | No | Abnormal flag |
| `remarks` | String | No | Component notes |

**Relationships:**
- N:1 ← Result (result_id)
- 1:1 ← TestComponent (component_id)

---

## Equipment & Inventory Tables

### Device
**Collection:** `devices`

Laboratory equipment and devices.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `name` | String | No | Device name |
| `serial_number` | String | Yes | Unique serial number |
| `cleaning_reagent` | String | No | Cleaning solution |
| `manufacturer` | String | No | Manufacturer name |
| `status` | Enum | No | active/inactive/maintenance |
| `staff_id` | ObjectId → Staff | No | Assigned staff |
| `capacity_of_sample` | Number | No | Sample capacity |
| `maintenance_schedule` | Enum | No | daily/weekly/monthly |
| `owner_id` | ObjectId → Owner | No | Lab owner reference |

**Relationships:**
- N:1 ← Owner (owner_id)
- 1:1 → Staff (staff_id)
- 1:N → Test (device_id)
- 1:N → OrderDetails (device_id)

---

### Inventory
**Collection:** `stockinventories`

Laboratory inventory and stock management.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `name` | String | No | Item name |
| `item_code` | String | No | Item code |
| `cost` | Number | No | Item cost |
| `expiration_date` | Date | No | Expiry date |
| `critical_level` | Number | No | Minimum stock level |
| `count` | Number | No | Current stock count |
| `balance` | Number | No | Available balance |
| `owner_id` | ObjectId → Owner | No | Lab owner reference |

**Relationships:**
- N:1 ← Owner (owner_id)
- 1:N → StockInput (item_id)
- 1:N → StockOutput (item_id)

**Related Tables:**
- **StockInput**: Stock additions
- **StockOutput**: Stock consumption

---

## Billing & Communication Tables

### Invoice
**Collection:** `invoices`

Billing and payment records.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `invoice_id` | String | Yes | Unique invoice identifier |
| `order_id` | ObjectId → Order | No | Reference to order |
| `invoice_date` | Date | Auto | Invoice creation date |
| `subtotal` | Number | No | Subtotal amount |
| `discount` | Number | No | Discount applied |
| `total_amount` | Number | No | Final amount |
| `amount_paid` | Number | No | Amount received |
| `payment_status` | Enum | No | pending/paid/partial |
| `payment_method` | Enum | No | cash/card/bank_transfer |
| `payment_date` | Date | No | Payment date |
| `paid_by` | ObjectId → Staff | No | Staff who recorded payment |
| `remarks` | String | No | Invoice notes |
| `owner_id` | ObjectId → Owner | No | Lab owner reference |
| `items[]` | Array | No | Invoice line items |

**Relationships:**
- N:1 ← Order (order_id)
- N:1 ← Owner (owner_id)
- N:1 ← Staff (paid_by)

---

### Notification
**Collection:** `notifications`

System notifications and messages.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `sender_id` | ObjectId | No | Message sender |
| `sender_model` | Enum | No | Admin/Owner/Doctor/Patient/Staff |
| `receiver_id` | ObjectId | Yes | Message recipient |
| `receiver_model` | Enum | Yes | Owner/Patient/Doctor/Admin/Staff |
| `type` | Enum | No | Message type |
| `title` | String | No | Message title |
| `message` | String | No | Message content |
| `related_id` | ObjectId | No | Related record ID |
| `is_read` | Boolean | No | Read status |
| `parent_id` | ObjectId → Notification | No | Parent message |
| `conversation_id` | ObjectId | No | Conversation group |
| `is_reply` | Boolean | No | Reply flag |

**Relationships:**
- Self-referencing for conversations
- Polymorphic relationships to all user types

---

## System Management Tables

### Feedback
**Collection:** `feedbacks`

User feedback and ratings.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `user_id` | ObjectId | Yes | Feedback giver |
| `user_model` | Enum | Yes | Doctor/Patient/Staff/Owner |
| `target_type` | Enum | Yes | lab/test/order/system/service |
| `target_id` | ObjectId | Cond | Target record ID |
| `target_model` | Enum | Cond | Owner/Test/Order |
| `rating` | Number (1-5) | Yes | Rating score |
| `message` | String | Yes | Feedback text |
| `is_anonymous` | Boolean | No | Anonymous flag |
| `response.message` | String | No | Admin response |
| `response.responded_by` | ObjectId → Staff | No | Response staff |
| `response.responded_at` | Date | No | Response timestamp |

**Relationships:**
- Polymorphic user relationships
- Polymorphic target relationships
- N:1 ← Staff (responded_by)

---

### AuditLog
**Collection:** `auditlogs`

System activity logging.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `_id` | ObjectId | Auto | Primary key |
| `staff_id` | ObjectId → Staff | No | Staff who performed action |
| `username` | String | No | Staff username |
| `action` | String | No | Action performed |
| `table_name` | String | No | Affected table |
| `record_id` | ObjectId | No | Affected record |
| `message` | String | No | Action description |
| `timestamp` | Date | Auto | Action timestamp |
| `owner_id` | ObjectId → Owner | No | Lab owner reference |

**Relationships:**
- N:1 ← Staff (staff_id)
- N:1 ← Owner (owner_id)

---

## Shared Schemas

### AddressSchema
**Embedded Schema** (not a collection)

Standardized address structure used across multiple models.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `street` | String | No | Street address |
| `city` | String | No | City name |
| `country` | String | No | Country (default: Palestine) |

**Virtual Field:**
- `formatted`: Returns formatted address string

---

## Relationship Summary

### One-to-One (1:1)
- Staff ↔ Device (staff_id)
- OrderDetails ↔ Result (detail_id)
- TestComponent ↔ ResultComponent (component_id)

### One-to-Many (1:N)
- Admin → Owner
- Owner → Staff
- Owner → Test
- Owner → Device
- Owner → Order
- Owner → Inventory
- Owner → Invoice
- Owner → AuditLog
- Patient → Order
- Doctor → Order
- Order → OrderDetails
- Order → Invoice
- Test → TestComponent
- Test → OrderDetails
- Result → ResultComponent
- Device → Test
- Device → OrderDetails
- Staff → OrderDetails
- Staff → Result
- Staff → Invoice
- Staff → AuditLog
- Staff → Feedback

### Many-to-Many (N:N)
- Through OrderDetails: Patient ↔ Test
- Through OrderDetails: Doctor ↔ Test
- Through Feedback: Users ↔ Targets

### Polymorphic Relationships
- Notification: sender/receiver can be any user type
- Feedback: user/target can be different model types
- Order: requested_by can be Patient or Doctor

### Self-Referencing
- Notification: parent/child relationships for conversations

---

## Key Business Rules

1. **Username Uniqueness**: All usernames must be unique across Admin, Owner, Staff, Doctor, and Patient collections
2. **Lab Isolation**: Each Owner manages their own Staff, Tests, Devices, Orders, etc.
3. **Test Assignment**: Tests are assigned to Staff, either manually or automatically via Device assignment
4. **Result Authorization**: Only assigned Staff can upload results for their tests
5. **Subscription Management**: Owners have subscription periods managed by Admins
6. **Patient Registration**: Orders can be created before patient registration using temp_patient_info
7. **Component Tests**: Complex tests have multiple components with individual results
8. **Audit Trail**: All staff actions are logged in AuditLog
9. **Notification System**: Users receive notifications for important events
10. **Feedback System**: Users can provide feedback on various aspects of the system