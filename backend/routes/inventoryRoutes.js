// routes/inventoryRoutes.js
const express = require('express');
const router = express.Router();
const { updateInventory } = require('../controllers/inventoryController');
const authMiddleware = require('../middleware/authMiddleware');

// ✅ Route: Update Inventory (Add/Use stock)
// Only accessible by Staff
router.post(
  '/update',
  authMiddleware(['Staff']), // only staff can access
  updateInventory
);

module.exports = router;
