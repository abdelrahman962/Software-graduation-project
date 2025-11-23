# Automated Patient Registration Flow

## Overview
The system now automatically sends registration links via Email and SMS when patients request tests, eliminating manual staff verification for account creation.

## Flow Diagram

### 1. Patient Submits Registration (Public)
```
Patient fills form → Order created (no barcode) → Email + SMS sent with registration link
```

### 2. Doctor Orders Tests for Patient
```
Doctor requests tests → Order created (no barcode) → Patient notified via Email + SMS
```

### 3. Patient Orders Tests (Self-Service)
```
Patient orders tests → Order created (no barcode) → Confirmation via Email + SMS
```

### 4. Patient Clicks Registration Link
```
Email/SMS link → Verify token → Pre-filled form → Create account → Order linked → Welcome email
```

### 5. Sample Collection & Barcode Generation
```
Patient visits lab → Staff verifies ID → Barcode generated → Attached to sample → Device processing
```

---

## Database Changes

### Order Model Updates
```javascript
{
  barcode: { 
    type: String, 
    unique: true, 
    sparse: true  // Allows null, generated only when sample collected
  },
  registration_token: { 
    type: String, 
    unique: true, 
    sparse: true  // For email/SMS registration link
  },
  registration_token_expires: { 
    type: Date  // Token valid for 7 days
  }
}
```

### Token Generation
- **Registration Token**: 64-character hex string (crypto.randomBytes(32))
- **Expiry**: 7 days from creation
- **Barcode**: Generated only when sample collected (format: `ORD-TIMESTAMP-RANDOM`)

---

## New Endpoints

### 1. Verify Registration Token
**GET** `/api/public/register/verify/:token`

**Response:**
```json
{
  "success": true,
  "registration_data": {
    "order_id": "...",
    "lab": { "name": "...", "phone": "...", "email": "..." },
    "patient_info": { "full_name": {...}, "email": "...", ... },
    "tests": [...],
    "total_cost": 250
  }
}
```

### 2. Complete Registration
**POST** `/api/public/register/complete`

**Body:**
```json
{
  "token": "64-char-hex-string",
  "username": "patient123",
  "password": "SecurePass123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Account created successfully!",
  "patient": {
    "patient_id": "1000",
    "username": "patient123",
    "full_name": {...},
    "email": "..."
  }
}
```

---

## Email & SMS Messages

### Patient Registration (Public Form)
**Email Subject:** `Complete Your Account Registration - [Lab Name]`

**Email Content:**
- Personalized greeting
- Registration link with token
- Order details (tests, cost)
- Link expiry (7 days)
- Next steps
- Lab contact info

**SMS:**
```
Hello [Name]! Complete your registration at [Lab]: [Link]. 
Tests: [count], Total: [cost] ILS. Link expires in 7 days.
```

### Doctor Orders Tests
**Email Subject:** `Test Order from Dr. [Doctor Name]`

**Email Content:**
- Doctor's test request notification
- Lab and test details
- Urgent flag (if applicable)
- Visit instructions
- Lab contact

**SMS:**
```
Dr. [Name] ordered [count] test(s) for you (URGENT). 
Visit [Lab] for sample collection. Tests: [list]
```

### Patient Orders Tests
**Email Subject:** `Test Order Confirmation - [Lab Name]`

**Email Content:**
- Order confirmation
- Test list and cost
- Sample collection instructions
- Urgent notification (if applicable)

**SMS:**
```
Your test order at [Lab] is confirmed (URGENT). 
[count] test(s), Total: [cost] ILS. Visit lab for sample collection.
```

### Welcome Email (After Registration)
**Subject:** `Welcome to [Lab Name]`

**Content:**
- Account credentials
- Login instructions
- Next steps (visit lab)
- Feature highlights

---

## Files Modified

### 1. **backend/models/Order.js**
- Added `registration_token` and `registration_token_expires` fields
- Made `barcode` optional (sparse index)
- Added `generateRegistrationToken()` static method

### 2. **backend/utils/sendSMS.js** (NEW)
- SMS utility function (Twilio ready)
- Console logging for development

### 3. **backend/controllers/publicController.js**
- Updated `submitRegistration()` - removed barcode, added token + email/SMS
- Added `verifyRegistrationToken()` endpoint
- Added `completeRegistration()` endpoint

### 4. **backend/controllers/doctorController.js**
- Updated `requestTestForPatient()` - removed barcode, added email/SMS notifications
- Imported `sendEmail` and `sendSMS` utilities

### 5. **backend/controllers/patientController.js**
- Updated `requestTest()` - removed barcode, added email/SMS confirmations
- Imported `sendEmail` and `sendSMS` utilities

### 6. **backend/routes/publicRoutes.js**
- Added `GET /register/verify/:token`
- Added `POST /register/complete`

---

## Benefits

### 1. **Patient Experience**
- ✅ Instant email + SMS confirmation
- ✅ Create account at convenience (not forced at lab)
- ✅ Pre-filled registration form (less typing)
- ✅ Secure token-based authentication
- ✅ Clear next steps via multiple channels

### 2. **Staff Efficiency**
- ✅ No manual account creation
- ✅ Only verify ID and collect sample
- ✅ Barcode generated when actually needed
- ✅ Reduced paperwork

### 3. **System Integrity**
- ✅ No wasted barcodes for no-shows
- ✅ Token expiry prevents stale registrations
- ✅ Unique barcode generation when sample ready
- ✅ Transaction safety with MongoDB sessions

### 4. **Communication**
- ✅ Multi-channel notifications (Email + SMS)
- ✅ Automated urgent test flagging
- ✅ Lab staff notifications for urgent requests
- ✅ Doctor notifications when patients order tests

---

## Frontend Implementation Notes

### Registration Completion Page
**Route:** `/register/complete?token=...`

**Steps:**
1. Extract token from URL query params
2. Call `GET /api/public/register/verify/:token`
3. Display pre-filled form with patient info (read-only)
4. Ask for username and password only
5. Submit to `POST /api/public/register/complete`
6. Redirect to login page on success

### Sample UI Flow
```
Token Verification → Loading...
                  ↓
Valid Token → Show Form (Username + Password)
           ↓
Submit → Account Created → Redirect to Login
```

---

## Security Considerations

1. **Token Security**
   - 256-bit random tokens (crypto.randomBytes(32))
   - 7-day expiration
   - One-time use (cleared after registration)
   - Unique + sparse index (no duplicates)

2. **Email/SMS Delivery**
   - TODO: Implement actual email service (Nodemailer, SendGrid)
   - TODO: Implement SMS service (Twilio, AWS SNS)
   - Currently logs to console for development

3. **Password Security**
   - Bcrypt hashing (10 rounds)
   - Password requirements should be enforced frontend

4. **Rate Limiting**
   - Registration endpoint uses `loginLimiter` middleware
   - Prevents spam/abuse

---

## Environment Variables Needed

```env
# Frontend URL for registration links
FRONTEND_URL=http://localhost:3000

# Email Service (Nodemailer example)
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password

# SMS Service (Twilio example)
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+1234567890

# JWT
JWT_SECRET=your-secret-key
```

---

## Testing Checklist

### Patient Registration Flow
- [ ] Submit registration form
- [ ] Verify email received with correct link
- [ ] Verify SMS received with correct link
- [ ] Click email link → Pre-filled form loads
- [ ] Create account → Success message
- [ ] Login with new credentials → Works
- [ ] Order linked to patient → Verified

### Doctor Orders Tests
- [ ] Doctor orders tests for patient
- [ ] Patient receives email notification
- [ ] Patient receives SMS notification
- [ ] Urgent tests trigger staff notifications
- [ ] Order created without barcode

### Patient Orders Tests
- [ ] Patient orders tests
- [ ] Confirmation email received
- [ ] Confirmation SMS received
- [ ] Order created without barcode
- [ ] Lab owner notified

### Token Expiry
- [ ] Token expires after 7 days
- [ ] Expired token shows error message
- [ ] Used token cannot be reused

### Barcode Generation
- [ ] Order created without barcode initially
- [ ] Barcode generated when sample collected (staff action)
- [ ] Unique barcodes (no duplicates)

---

## Migration Notes

### Existing Orders
Orders created before this update will have:
- `barcode: null` (acceptable due to sparse index)
- `registration_token: null`
- No impact on existing functionality

### Staff Workflow Update
Staff should now:
1. Wait for patient to arrive at lab
2. Verify patient ID
3. Generate barcode (new endpoint needed)
4. Attach barcode to sample
5. Collect sample

**TODO:** Create staff endpoint for barcode generation:
```
POST /api/staff/orders/:orderId/generate-barcode
```

---

## Future Enhancements

1. **Barcode Printing**
   - Staff endpoint to generate barcode
   - Print barcode label from browser
   - QR code option for mobile scanning

2. **SMS Templates**
   - Multilingual support (Arabic, Hebrew, English)
   - Template management in admin panel
   - SMS credit tracking

3. **Email Templates**
   - Rich HTML email templates
   - Lab branding customization
   - Email open tracking

4. **Reminder System**
   - SMS reminder 24 hours before sample collection
   - Email reminder if token unused after 5 days
   - Auto-cancel expired registrations

5. **Mobile App Deep Links**
   - Open registration in mobile app
   - Push notifications instead of SMS
   - In-app registration completion
