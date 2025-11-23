const express = require('express');
const router = express.Router();
const labBranchController = require('../controllers/labBranchController');
const authenticateToken = require('../middleware/authMiddleware');
const checkRole = require('../middleware/roleMiddleware');
const { 
  validateBranchCreation, 
  validateBranchUpdate,
  validateNearestSearch 
} = require('../validators/labBranchValidator');

// ============================================================================
// PUBLIC ROUTES (for patients - no authentication required)
// ============================================================================

// Lab branch search
router.get('/all', labBranchController.getAllAvailableLabs);  // Browse all lab branches with pagination
router.get('/nearest', ...validateNearestSearch, labBranchController.findNearestBranches);  // Find nearest branches
router.get('/search', labBranchController.searchBranches);  // Search branches by city/services

// Owner routes (manage their own branches)
router.post(
  '/',
  authenticateToken,
  checkRole(['owner']),
  ...validateBranchCreation,
  labBranchController.createBranch
);

router.get(
  '/my-branches',
  authenticateToken,
  checkRole(['owner']),
  labBranchController.getOwnerBranches
);

router.get(
  '/:id',
  authenticateToken,
  checkRole(['owner']),
  labBranchController.getBranchById
);

router.put(
  '/:id',
  authenticateToken,
  checkRole(['owner']),
  ...validateBranchUpdate,
  labBranchController.updateBranch
);

router.delete(
  '/:id',
  authenticateToken,
  checkRole(['owner']),
  labBranchController.deleteBranch
);

// Admin routes
router.get(
  '/admin/all',
  authenticateToken,
  checkRole(['admin']),
  labBranchController.getAllBranches
);

module.exports = router;
