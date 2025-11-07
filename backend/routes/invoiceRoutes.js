const express = require('express');
const router = express.Router();
const invoiceController = require('../controllers/invoiceController'); // ✅ Correct import
const Invoice = require('../models/Invoices');
const authMiddleware = require('../middleware/authMiddleware');

// 🧾 Get all invoices (only LabOwner and Admin)
router.get('/', authMiddleware(['LabOwner', 'Admin']), async (req, res) => {
  try {
    const invoices = await Invoice.find().populate('order_id');
    res.json({ invoices });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 💳 Mark invoice as paid (LabOwner or Staff)
router.patch('/:invoiceId/pay', authMiddleware(['LabOwner', 'Staff']),invoiceController.markInvoicePaid);




// ✅ Get Invoice by ID
router.get(
  '/:invoiceId',
  authMiddleware(['Admin', 'LabOwner', 'Staff']),
  invoiceController.getInvoiceById
);

// ✅ Get all invoices for a Lab Owner
router.get(
  '/lab-owner/:owner_id',
  authMiddleware(['LabOwner', 'Admin']),
  invoiceController.getInvoicesByLabOwner
);

// ✅ Get invoices by Patient
router.get(
  '/patient/:patient_id',
  authMiddleware(['Patient', 'Admin', 'LabOwner']),
  invoiceController.getInvoicesByPatient
);

// ✅ Apply Discount to an Invoice
router.put(
  '/:invoiceId/discount',
  authMiddleware(['LabOwner', 'Admin']),
  invoiceController.applyDiscount
);

module.exports = router;






module.exports = router;
