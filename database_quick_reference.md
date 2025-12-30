# Medical Lab System - Quick Reference

## Table Field Definitions

### Admin
**Collection:** `admins`
- `_id` (ObjectId) - Primary key
- `full_name.first` (String) - First name
- `full_name.middle` (String) - Middle name
- `full_name.last` (String) - Last name
- `identity_number` (String, unique) - ID number
- `birthday` (Date) - Date of birth
- `gender` (Enum: Male/Female/Other) - Gender
- `phone_number` (String) - Contact number
- `admin_id` (String, unique) - Admin identifier
- `email` (String, unique) - Email address
- `username` (String, unique) - Login username
- `password` (String) - Hashed password

### Owner
**Collection:** `labowners`
- `_id` (ObjectId) - Primary key
- `subscriptionFee` (Number) - Monthly fee
- `subscription_period_months` (Number) - Subscription duration
- `lab_name` (String) - Laboratory name
- `lab_license_number` (String) - Lab license
- `owner_id` (String, unique) - Owner identifier
- `name.first` (String, required) - First name
- `name.middle` (String) - Middle name
- `name.last` (String, required) - Last name
- `identity_number` (String, required, unique) - ID number
- `birthday` (Date, required) - Date of birth
- `gender` (Enum: Male/Female/Other, required) - Gender
- `social_status` (Enum: Single/Married/Divorced/Widowed) - Marital status
- `phone_number` (String, required) - Contact number
- `address` (AddressSchema) - Address object
- `qualification` (String) - Professional qualification
- `profession_license` (String) - License number
- `bank_iban` (String) - Bank account
- `email` (String, required, unique) - Email
- `username` (String, unique) - Login username
- `password` (String) - Hashed password
- `date_subscription` (Date) - Subscription start
- `admin_id` (ObjectId → Admin, required) - Admin reference
- `subscription_end` (Date) - Subscription expiry
- `is_active` (Boolean) - Lab active status
- `status` (Enum: pending/approved/rejected) - Approval status
- `rejection_reason` (String) - Rejection explanation
- `temp_credentials` (Object) - Temporary login

### Staff
**Collection:** `staffs`
- `_id` (ObjectId) - Primary key
- `full_name.first` (String, required) - First name
- `full_name.middle` (String) - Middle name
- `full_name.last` (String, required) - Last name
- `identity_number` (String, required, unique) - ID number
- `birthday` (Date, required) - Date of birth
- `gender` (Enum: Male/Female/Other, required) - Gender
- `social_status` (Enum: Single/Married/Divorced/Widowed) - Marital status
- `phone_number` (String, required) - Contact number
- `address` (AddressSchema) - Address object
- `qualification` (String) - Professional qualification
- `profession_license` (String) - License number
- `employee_number` (String, unique) - Employee ID
- `bank_iban` (String) - Bank account
- `salary` (Number) - Monthly salary
- `employee_evaluation` (String) - Performance review
- `email` (String, required, unique) - Email
- `username` (String, required, unique) - Login username
- `password` (String, required) - Hashed password
- `date_hired` (Date) - Employment start date
- `last_login` (Date) - Last login timestamp
- `owner_id` (ObjectId → Owner, required) - Lab owner reference
- `login_history` ([Date]) - Login timestamps

### Patient
**Collection:** `patients`
- `_id` (ObjectId) - Primary key
- `full_name.first` (String, required) - First name
- `full_name.middle` (String) - Middle name
- `full_name.last` (String, required) - Last name
- `identity_number` (String, required, unique) - ID number
- `birthday` (Date) - Date of birth
- `gender` (Enum: Male/Female/Other) - Gender
- `social_status` (Enum: Single/Married/Divorced/Widowed) - Marital status
- `phone_number` (String) - Contact number
- `address` (AddressSchema) - Address object
- `patient_id` (String, unique) - Patient identifier
- `insurance_provider` (String) - Insurance company
- `insurance_number` (String) - Insurance policy number
- `notes` (String) - Medical notes
- `email` (String, unique) - Email address
- `username` (String) - Login username
- `password` (String, required) - Hashed password
- `created_by_staff` (ObjectId → Staff) - Staff who registered patient
- `last_login` (Date) - Last login timestamp

### Doctor
**Collection:** `doctors`
- `_id` (ObjectId) - Primary key
- `doctor_id` (Number, required, unique) - Doctor identifier
- `name.first` (String, required) - First name
- `name.middle` (String) - Middle name
- `name.last` (String, required) - Last name
- `identity_number` (String, required, unique) - ID number
- `birthday` (Date, required) - Date of birth
- `gender` (Enum: Male/Female/Other, required) - Gender
- `phone_number` (String, required) - Contact number
- `email` (String, required, unique) - Email
- `username` (String, required, unique) - Login username
- `password` (String, required) - Hashed password
- `specialty` (String) - Medical specialty
- `license_number` (String) - Medical license
- `years_of_experience` (Number) - Years of experience

### Order
**Collection:** `orders`
- `_id` (ObjectId) - Primary key
- `patient_id` (ObjectId → Patient, required) - Patient reference
- `address` (AddressSchema) - Delivery address
- `temp_patient_info` (Object) - Temporary patient data
- `requested_by` (ObjectId) - Who requested order
- `requested_by_model` (Enum: Patient/Doctor) - Requester type
- `doctor_id` (ObjectId → Doctor) - Referring doctor
- `order_date` (Date) - Order creation date
- `status` (Enum: pending/processing/completed) - Order status
- `remarks` (String) - Order notes
- `owner_id` (ObjectId → Owner, required) - Lab owner reference
- `is_patient_registered` (Boolean) - Patient registration status
- `registration_token` (String, unique) - Account registration token
- `registration_token_expires` (Date) - Token expiry

### OrderDetails
**Collection:** `orderdetails`
- `_id` (ObjectId) - Primary key
- `order_id` (ObjectId → Order) - Parent order reference
- `test_id` (ObjectId → Test) - Test reference
- `device_id` (ObjectId → Device) - Assigned device
- `staff_id` (ObjectId → Staff) - Assigned staff
- `assigned_at` (Date) - Assignment timestamp
- `sample_collected` (Boolean) - Sample collection status
- `sample_collected_date` (Date) - Collection timestamp
- `status` (Enum: pending/assigned/urgent/collected/in_progress/completed) - Processing status

### Test
**Collection:** `testmanagements`
- `_id` (ObjectId) - Primary key
- `test_code` (String, required) - Unique test code
- `test_name` (String, required) - Test name
- `sample_type` (String) - Type of sample required
- `tube_type` (String) - Tube/container type
- `is_active` (Boolean) - Test availability
- `device_id` (ObjectId → Device) - Required device
- `method` (String) - Testing method
- `units` (String) - Result units
- `reference_range` (String) - Normal reference range
- `price` (Number) - Test price
- `owner_id` (ObjectId → Owner, required) - Lab owner reference
- `turnaround_time` (Number) - Expected completion time (hours)
- `collection_time` (String) - Sample collection time
- `reagent` (String) - Required reagents

### TestComponent
**Collection:** `testcomponents`
- `_id` (ObjectId) - Primary key
- `test_id` (ObjectId → Test, required) - Parent test reference
- `component_name` (String, required) - Component name
- `component_code` (String) - Component code
- `units` (String) - Component units
- `reference_range` (String) - Component reference range
- `min_value` (Number) - Minimum normal value
- `max_value` (Number) - Maximum normal value
- `display_order` (Number) - Display sequence
- `is_active` (Boolean) - Component availability
- `description` (String) - Component description

### Result
**Collection:** `results`
- `_id` (ObjectId) - Primary key
- `detail_id` (ObjectId → OrderDetails) - Order detail reference
- `result_value` (String) - Single result value
- `units` (String) - Result units
- `reference_range` (String) - Reference range
- `remarks` (String) - Result notes
- `has_components` (Boolean) - Multiple components flag
- `is_abnormal` (Boolean) - Abnormal result flag
- `abnormal_components_count` (Number) - Count of abnormal components
- `staff_id` (ObjectId → Staff) - Staff who uploaded result

### ResultComponent
**Collection:** `resultcomponents`
- `_id` (ObjectId) - Primary key
- `result_id` (ObjectId → Result, required) - Parent result reference
- `component_id` (ObjectId → TestComponent, required) - Test component reference
- `component_name` (String, required) - Component name
- `component_value` (String, required) - Result value
- `units` (String) - Component units
- `reference_range` (String) - Component reference range
- `is_abnormal` (Boolean) - Abnormal flag
- `remarks` (String) - Component notes

### Device
**Collection:** `devices`
- `_id` (ObjectId) - Primary key
- `name` (String) - Device name
- `serial_number` (String, unique) - Unique serial number
- `cleaning_reagent` (String) - Cleaning solution
- `manufacturer` (String) - Manufacturer name
- `status` (Enum: active/inactive/maintenance) - Device status
- `staff_id` (ObjectId → Staff) - Assigned staff
- `capacity_of_sample` (Number) - Sample capacity
- `maintenance_schedule` (Enum: daily/weekly/monthly) - Maintenance frequency
- `owner_id` (ObjectId → Owner) - Lab owner reference

### Inventory
**Collection:** `stockinventories`
- `_id` (ObjectId) - Primary key
- `name` (String) - Item name
- `item_code` (String) - Item code
- `cost` (Number) - Item cost
- `expiration_date` (Date) - Expiry date
- `critical_level` (Number) - Minimum stock level
- `count` (Number) - Current stock count
- `balance` (Number) - Available balance
- `owner_id` (ObjectId → Owner) - Lab owner reference

### Invoice
**Collection:** `invoices`
- `_id` (ObjectId) - Primary key
- `invoice_id` (String, unique) - Unique invoice identifier
- `order_id` (ObjectId → Order) - Order reference
- `invoice_date` (Date) - Invoice creation date
- `subtotal` (Number) - Subtotal amount
- `discount` (Number) - Discount applied
- `total_amount` (Number) - Final amount
- `amount_paid` (Number) - Amount received
- `payment_status` (Enum: pending/paid/partial) - Payment status
- `payment_method` (Enum: cash/card/bank_transfer) - Payment method
- `payment_date` (Date) - Payment date
- `paid_by` (ObjectId → Staff) - Staff who recorded payment
- `remarks` (String) - Invoice notes
- `owner_id` (ObjectId → Owner) - Lab owner reference
- `items[]` (Array) - Invoice line items

### Notification
**Collection:** `notifications`
- `_id` (ObjectId) - Primary key
- `sender_id` (ObjectId) - Message sender
- `sender_model` (Enum: Admin/Owner/Doctor/Patient/Staff) - Sender type
- `receiver_id` (ObjectId, required) - Message recipient
- `receiver_model` (Enum: Owner/Patient/Doctor/Admin/Staff, required) - Receiver type
- `type` (Enum: subscription/system/maintenance/test_result/urgent_result/request/payment/inventory/message/issue/feedback) - Message type
- `title` (String) - Message title
- `message` (String) - Message content
- `related_id` (ObjectId) - Related record ID
- `is_read` (Boolean) - Read status
- `parent_id` (ObjectId → Notification) - Parent message
- `conversation_id` (ObjectId) - Conversation group
- `is_reply` (Boolean) - Reply flag

### Feedback
**Collection:** `feedbacks`
- `_id` (ObjectId) - Primary key
- `user_id` (ObjectId, required) - Feedback giver
- `user_model` (Enum: Doctor/Patient/Staff/Owner, required) - User type
- `target_type` (Enum: lab/test/order/system/service, required) - Target type
- `target_id` (ObjectId) - Target record ID
- `target_model` (Enum: Owner/Test/Order) - Target model type
- `rating` (Number 1-5, required) - Rating score
- `message` (String, required) - Feedback text
- `is_anonymous` (Boolean) - Anonymous flag
- `response.message` (String) - Admin response
- `response.responded_by` (ObjectId → Staff) - Response staff
- `response.responded_at` (Date) - Response timestamp

### AuditLog
**Collection:** `auditlogs`
- `_id` (ObjectId) - Primary key
- `staff_id` (ObjectId → Staff) - Staff who performed action
- `username` (String) - Staff username
- `action` (String) - Action performed
- `table_name` (String) - Affected table
- `record_id` (ObjectId) - Affected record
- `message` (String) - Action description
- `timestamp` (Date) - Action timestamp
- `owner_id` (ObjectId → Owner) - Lab owner reference

## Core Business Objects & Relationships

### User Roles & Hierarchy
```
Admin
├── Manages → Owner (1:N)
└── Oversees → All Labs

Owner (Lab Manager)
├── Employs → Staff (1:N)
├── Owns → Device (1:N)
├── Offers → Test (1:N)
├── Receives → Order (1:N)
├── Manages → Inventory (1:N)
├── Issues → Invoice (1:N)
└── Audits → AuditLog (1:N)

Staff (Technician)
├── Assigned → Device (1:1)
├── Processes → OrderDetails (1:N)
├── Uploads → Result (1:N)
├── Records → Invoice Payments (1:N)
├── Logs → AuditLog (1:N)
└── Responds → Feedback (1:N)

Patient
├── Places → Order (1:N)
├── Receives → Notification (1:N)
└── Provides → Feedback (1:N)

Doctor
├── Orders → Test for Patient (1:N)
├── Receives → Notification (1:N)
└── Provides → Feedback (1:N)
```

### Order Processing Flow
```
Order (Header)
├── Contains → OrderDetails (1:N)
├── Generates → Invoice (1:1)
└── Belongs → Patient (N:1)

OrderDetails (Line Items)
├── References → Test (N:1)
├── Assigned → Staff (N:1)
├── Uses → Device (N:1)
└── Produces → Result (1:1)

Test
├── Has → TestComponent (1:N)
├── Requires → Device (N:1)
├── Ordered → OrderDetails (1:N)
└── Billed → Invoice.items (1:N)

Result
├── Has → ResultComponent (1:N)
├── Uploaded → Staff (N:1)
└── Links → OrderDetails (1:1)
```

### Equipment & Resources
```
Device
├── Assigned → Staff (1:1)
├── Used → Test (1:N)
├── Processes → OrderDetails (1:N)
└── Owned → Owner (N:1)

Inventory
├── StockInput (1:N)
├── StockOutput (1:N)
└── Owned → Owner (N:1)
```

### Communication & Feedback
```
Notification
├── Polymorphic sender/receiver
├── Conversation threading
└── Multiple types (system, urgent, etc.)

Feedback
├── Polymorphic user/target
├── Rating system (1-5)
├── Anonymous option
└── Staff responses
```

## Key Business Rules

### Data Integrity
- **Username Uniqueness**: Across all user types (Admin, Owner, Staff, Doctor, Patient)
- **Lab Isolation**: Owner acts as data partition boundary
- **Staff Authorization**: Only assigned staff can upload results
- **Device Assignment**: One staff per device, one device per test type

### Workflow Constraints
- **Order Creation**: Can use temp patient data before registration
- **Test Assignment**: Auto-assigned via device, or manual staff assignment
- **Result Upload**: Requires staff assignment + sample collection
- **Payment Processing**: Invoices track partial payments

### System Management
- **Subscription Model**: Owners pay monthly fees managed by Admins
- **Audit Trail**: All staff actions logged with lab context
- **Notification System**: Automated alerts for critical events
- **Feedback Loop**: Continuous improvement via user input

## Critical Paths

### Patient Test Flow
```
Patient Registration → Order Creation → Test Assignment → Sample Collection → Result Upload → Invoice Generation → Payment
```

### Staff Workflow
```
Login → View Assigned Tests → Collect Samples → Process Tests → Upload Results → Handle Payments
```

### Lab Management
```
Owner Registration → Staff Hiring → Device Setup → Test Configuration → Order Processing → Revenue Tracking
```

## Performance Considerations

### Indexes Required
- `OrderDetails`: (staff_id, status), (device_id, status)
- `Result`: (detail_id)
- `TestComponent`: (test_id, display_order)
- `Notification`: (receiver_id, is_read), (conversation_id, createdAt)
- `Feedback`: (user_id, createdAt), (rating, createdAt)

### Data Partitioning
- **By Owner**: Most collections filtered by owner_id
- **By Date**: Orders, Results, Invoices partitioned by date ranges
- **By Status**: Active vs archived records

### Caching Strategy
- **User Sessions**: Redis for authentication tokens
- **Reference Data**: Tests, Components cached per lab
- **Dashboard Data**: Pre-computed metrics for performance