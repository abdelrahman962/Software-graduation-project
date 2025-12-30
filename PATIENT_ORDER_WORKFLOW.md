# Medical Lab System - Patient Order Creation Demo

This guide demonstrates how to create a complete patient order workflow including patient registration, test ordering, and invoice generation.

## Overview

The system supports creating patient orders through multiple channels:
- **Walk-in patients** (come directly to lab) - handled by staff
- **Online bookings** (patients book through website) - handled by patients
- **Doctor referrals** (referred by doctors) - handled by doctors

## Complete Workflow

### 1. Patient Registration
- New patients get automatically registered with generated credentials
- Existing patients are matched by phone number and name
- Credentials sent via WhatsApp and email

### 2. Order Creation
- Order created with date, status, and requester info
- Tests assigned to order with individual status tracking

### 3. Invoice Generation
- Automatic invoice creation with test pricing
- Payment marked as "paid" for walk-in patients
- PDF invoice sent to patient

### 4. Test Processing
- Tests assigned to available staff
- Sample collection and result upload workflow
- HL7 simulation for automated results

## API Endpoints Used

### Staff Endpoints (for walk-in orders)
```
POST /api/staff/login
GET  /api/staff/lab-tests
POST /api/staff/create-walk-in-order
```

### Patient Endpoints (for online orders)
```
POST /api/patient/login
GET  /api/patient/profile
POST /api/patient/create-order
```

### Doctor Endpoints (for referrals)
```
POST /api/doctor/login
POST /api/doctor/create-order
```

## Demo Scripts

### 1. API Demonstration Script
File: `demonstrate_order_creation.js`

**Usage:**
```bash
# Show instructions
node demonstrate_order_creation.js --help

# Run the demo
node demonstrate_order_creation.js
```

**What it does:**
- Tests backend connectivity
- Demonstrates staff login
- Lists available tests
- Creates complete patient order
- Shows all generated data

### 2. Database Direct Script
File: `backend/create_sample_order.js`

**Usage:**
```bash
cd backend

# List available data
node create_sample_order.js --list

# Create sample order
node create_sample_order.js --create
```

**What it does:**
- Direct database operations
- Creates sample data without API calls
- Useful for testing database structure

## Sample Data Created

### Patient
```json
{
  "patient_id": "AUTO_GENERATED",
  "username": "demo.patient",
  "password": "AUTO_GENERATED",
  "full_name": {
    "first": "Demo",
    "last": "Patient"
  },
  "phone_number": "+972507654321",
  "email": "demo.patient@example.com"
}
```

### Order
```json
{
  "order_date": "2025-12-26T10:30:00.000Z",
  "status": "processing",
  "is_patient_registered": true,
  "tests": ["Complete Blood Count"]
}
```

### Invoice
```json
{
  "invoice_id": "INV-000001",
  "total_amount": 150,
  "payment_status": "paid",
  "payment_method": "cash",
  "items": [
    {
      "test_name": "Complete Blood Count",
      "price": 150,
      "quantity": 1
    }
  ]
}
```

## Prerequisites

1. **MongoDB Running**
   ```bash
   # Make sure MongoDB is started
   mongod
   ```

2. **Backend Server Running**
   ```bash
   cd backend
   npm install
   npm start
   ```

3. **Staff Account**
   - Need at least one staff account in database
   - Update credentials in demo script

4. **Test Data**
   - Need at least one test configured
   - Tests must be assigned to a lab owner

## Step-by-Step Manual Process

### 1. Create Patient (if new)
```javascript
POST /api/staff/create-walk-in-order
{
  "patient_info": {
    "full_name": {"first": "John", "last": "Doe"},
    "phone_number": "+972501234567",
    "email": "john@example.com",
    "identity_number": "123456789",
    "birthday": "1990-01-01",
    "gender": "male"
  },
  "test_ids": ["TEST_ID_HERE"],
  "doctor_id": null
}
```

### 2. Order is Automatically Created
- Order linked to patient
- Order details created for each test
- Invoice generated and marked as paid

### 3. Process Tests
- Assign tests to staff
- Collect samples
- Run tests (manual or HL7 simulation)
- Upload results

## Database Schema

### Key Collections
- **patients**: Patient information and credentials
- **orders**: Order header with patient and date info
- **orderdetails**: Individual test assignments
- **invoices**: Payment and billing information
- **results**: Test results (after completion)
- **notifications**: Communication records

### Relationships
```
Patient → Order → OrderDetails → Results
    ↓         ↓
  Invoice    Invoice
```

## Testing the Workflow

1. **Run Demo Script**
   ```bash
   node demonstrate_order_creation.js
   ```

2. **Check Database**
   - Verify patient created
   - Verify order and order details
   - Verify invoice generation

3. **Test Frontend**
   - Login as staff
   - View orders and patients
   - Process tests

4. **Test Patient Portal**
   - Login with generated credentials
   - View order history
   - Check notifications

## Error Handling

### Common Issues
- **No staff account**: Create staff account first
- **No tests available**: Add tests to database
- **MongoDB not running**: Start MongoDB service
- **Backend not running**: Start backend server

### Validation
- Patient phone + name uniqueness
- Test availability for lab
- Staff authorization
- Payment status validation

## Notifications

### Automatic Notifications
- **New Patient**: Account credentials via WhatsApp + Email
- **Invoice**: PDF invoice via WhatsApp + Email
- **Results**: Test results via WhatsApp + Email
- **Status Updates**: Order status changes

### Notification Types
- `payment`: Invoice generation
- `result`: Test results available
- `account`: Account activation
- `appointment`: Scheduling updates

## Security Considerations

- Passwords automatically hashed
- JWT tokens for authentication
- Role-based access control
- Input validation and sanitization
- SQL injection prevention

## Next Steps

After creating the order:
1. **Assign Tests**: Assign specific tests to staff members
2. **Sample Collection**: Mark samples as collected
3. **Run Tests**: Use HL7 simulation or manual entry
4. **Upload Results**: Save test results
5. **Generate Reports**: Create PDF reports for patients

This completes the patient order creation workflow! 🎉