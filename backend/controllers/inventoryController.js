const { StockInventory, StockInput, StockOutput } = require('../models/Inventory');
const Staff = require('../models/Staff');
const logAction = require('../utils/logAction');

/**
 * Update inventory: either add stock (input) or use stock (output)
 * Ensures staff can only modify items belonging to their LabOwner
 */
exports.updateInventory = async (req, res) => {
  try {
    const { staff_id, item_id, quantity } = req.body;

    if (!staff_id || !item_id || !quantity) {
      return res.status(400).json({ message: "staff_id, item_id, and quantity are required" });
    }

    // ✅ Fetch staff to get their owner_id
    const staff = await Staff.findById(staff_id);
    if (!staff) return res.status(404).json({ message: "Staff not found" });

    const item = await StockInventory.findById(item_id);
    if (!item) return res.status(404).json({ message: "Inventory item not found" });

    // ✅ Check ownership
    if (item.owner_id.toString() !== staff.owner_id.toString()) {
      return res.status(403).json({ message: "You cannot modify inventory from another lab" });
    }

    if (quantity < 0 && item.count < Math.abs(quantity)) {
      return res.status(400).json({ message: "Insufficient stock for usage" });
    }

    // Determine action type
    let actionType;
    if (quantity > 0) {
      await StockInput.create({
        item_id,
        input_value: quantity,
        input_date: new Date()
      });
      actionType = "Stock Added";
    } else if (quantity < 0) {
      const usedQuantity = Math.abs(quantity);
      await StockOutput.create({
        item_id,
        output_value: usedQuantity,
        out_date: new Date()
      });
      actionType = "Stock Used";
    }

    // Update inventory count
    item.count += quantity; // positive adds, negative subtracts
    await item.save();

    // Log action
    await logAction(staff_id, `${actionType}: ${Math.abs(quantity)} of ${item.name}`);

    res.json({ message: `${actionType} successfully`, item });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: err.message });
  }
};
