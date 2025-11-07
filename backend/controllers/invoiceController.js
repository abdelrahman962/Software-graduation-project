const OrderDetail = require('../models/OrderDetails');
const Test = require('../models/Test');
const Invoice = require('../models/Invoices');
const Order = require('../models/Order');
const logAction = require('../utils/logAction');




// ✅ Apply Discount to an Invoice
exports.applyDiscount = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const { discount } = req.body;

    const invoice = await Invoice.findById(invoiceId);
    if (!invoice) return res.status(404).json({ message: "Invoice not found" });

    invoice.discount = discount;
    invoice.total_amount = invoice.subtotal - discount;
    await invoice.save();

    await logAction(req.user?._id, `Applied discount of ${discount} to invoice ${invoiceId}`);

    res.json({ message: "Discount applied", invoice });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
