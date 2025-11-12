const mongoose = require('mongoose');

const deviceSchema = new mongoose.Schema({
  name: String,
  serial_number: { type: String, unique: true },
  cleaning_reagent: String,
  manufacturer: String,
  status: { type: String, enum: ['active','inactive','maintenance'], default: 'active' },
  staff_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' },
  capacity_of_sample: Number,
  maintenance_schedule: { type: String, enum: ['daily','weekly','monthly'] },
  owner_id: { type: mongoose.Schema.Types.ObjectId, ref: 'LabOwner' }
});

module.exports = mongoose.model('Device', deviceSchema);



/*
{
    "success": true,
    "message": "✅ Registration submitted successfully! Please visit the lab for verification.",
    "registration": {
        "order_id": "691488ce1e87997695607712",
        "barcode": "ORD-1762953422785",
        "patient_name": "Ahmed Salem",
        "email": "ahmed.salem@example.com",
        "phone_number": "01123456789",
        "tests_ordered": [
            {
                "test_name": "Liver Function Test",
                "test_code": "LFT-005",
                "price": 220
            },
            {
                "test_name": "Hemoglobin A1c (HbA1c)",
                "test_code": "HBA1C-004",
                "price": 180
            },
            {
                "test_name": "Vitamin D (25-Hydroxyvitamin D)",
                "test_code": "VITD-007",
                "price": 280
            }
        ],
        "total_cost": 680,
        "tests_count": 3,
        "status": "pending",
        "next_steps": [
            "Visit the lab with your ID",
            "Show your registration barcode to staff",
            "Staff will verify your information and create your account",
            "You'll receive your account credentials via email"
        ]
    }
}   */