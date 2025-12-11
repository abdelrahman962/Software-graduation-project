const Staff = require("../models/Staff");
const Patient = require("../models/Patient");
const Order = require("../models/Order");
const Test = require("../models/Test");
const OrderDetails = require("../models/OrderDetails");
const Result = require("../models/Result");
const Invoice = require("../models/Invoices");
const { Inventory } = require("../models/Inventory");
const { StockOutput } = require("../models/Inventory");
const Device = require("../models/Device");
const Notification = require("../models/Notification");
const Feedback = require("../models/Feedback");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const sendEmail = require("../utils/sendEmail");
const logAction = require("../utils/logAction");


// ✅ Staff Login (with login history + logging)
exports.loginStaff = async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log('Login attempt:', { username, passwordProvided: !!password });

    const staff = await Staff.findOne({ $or: [{ username }, { email: username }] });
    console.log('Staff found:', staff ? { id: staff._id, username: staff.username, email: staff.email, hasPassword: !!staff.password } : 'No staff found');

    if (!staff || !(await staff.comparePassword(password))) {
      console.log('Login failed: invalid credentials');
      return res.status(401).json({ message: "Invalid credentials" });
    }

    // ✅ Record latest login
    staff.last_login = new Date();

    // ✅ Keep full login history (optional)
    if (!Array.isArray(staff.login_history)) {
      staff.login_history = [];
    }
    staff.login_history.push(staff.last_login);

    await staff.save();

    // ✅ Log the action for tracking by the lab owner
    await logAction(staff._id, staff.username, `Staff logged in at ${staff.last_login}`);

    const token = jwt.sign({ id: staff._id, role:'Staff', username:staff.username }, process.env.JWT_SECRET, { expiresIn: "7d" });
    res.json({ message: "Login successful", token, staff });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


exports.uploadResult = async (req, res) => {
  try {
    const staff_id = req.user.id; // Use authenticated staff ID
    const { detail_id, result_value, remarks } = req.body;

    // Validate required fields
    if (!detail_id || !result_value) {
      return res.status(400).json({ message: "detail_id and result_value are required" });
    }

    // 1️⃣ Load order detail with related test + order
    const detail = await OrderDetails.findById(detail_id)
      .populate("test_id")
      .populate({
        path: "order_id",
        populate: [{ path: "patient_id" }, { path: "doctor_id" }, { path: "owner_id" }]
      });

    if (!detail) return res.status(404).json({ message: "Order detail not found" });

    // Check if the test is assigned to this staff
    if (!detail.staff_id || detail.staff_id.toString() !== staff_id.toString()) {
      return res.status(403).json({ message: "You are not authorized to upload results for this test" });
    }

    const test = detail.test_id;
    const order = detail.order_id;

    // 2️⃣ Check if the result is outside normal range → urgent
    let isUrgent = false;
    if (test.reference_range && typeof test.reference_range === "string") {
      const [min, max] = test.reference_range.split("-").map(v => parseFloat(v.trim()));
      const resultNum = parseFloat(result_value);
      if (resultNum < min || resultNum > max) isUrgent = true;
    }

    // 3️⃣ Save result
    const result = await Result.create({
      detail_id,
      staff_id, // Track who uploaded the result
      result_value,
      units: test.units,
      reference_range: test.reference_range,
      remarks
    });

    // 3️⃣.5 Update OrderDetails status to 'completed' and link result
    detail.status = 'completed';
    detail.result_id = result._id;
    await detail.save();

    // 4️⃣ Send notifications
    const notifications = [];

    if (isUrgent) {
      // Mark order as urgent
      order.remarks = "urgent";
      await order.save();

      // 🔔 To the Doctor (if exists)
      if (order.doctor_id) {
        notifications.push({
          sender_id: staff_id,
          sender_model: "Staff",
          receiver_id: order.doctor_id._id,
          receiver_model: "Doctor",
          type: "test_result",
          title: "Urgent Test Result",
          message: `Test ${test.test_name} result for patient ${order.patient_id?.full_name?.first || ""} ${order.patient_id?.full_name?.last || ""} is outside normal range.`,
          related_id: result._id
        });
      }

      // 🔔 To the Patient (urgent)
      if (order.patient_id) {
        notifications.push({
          sender_id: staff_id,
          sender_model: "Staff",
          receiver_id: order.patient_id._id,
          receiver_model: "Patient",
          type: "test_result",
          title: "⚠️ Urgent Test Result Available",
          message: `Your test result for ${test.test_name} is outside the normal range. Please contact your doctor.`,
          related_id: result._id
        });
      }
    } else {
      // 🔔 To the Patient (normal result)
      if (order.patient_id) {
        notifications.push({
          sender_id: staff_id,
          sender_model: "Staff",
          receiver_id: order.patient_id._id,
          receiver_model: "Patient",
          type: "test_result",
          title: "✅ Test Result Available",
          message: `Your test result for ${test.test_name} is now available. You can view it in your dashboard.`,
          related_id: result._id
        });
      }

      // 🔔 To the Doctor (normal result)
      if (order.doctor_id) {
        notifications.push({
          sender_id: staff_id,
          sender_model: "Staff",
          receiver_id: order.doctor_id._id,
          receiver_model: "Doctor",
          type: "test_result",
          title: "✅ Test Result Available",
          message: `Test ${test.test_name} result for patient ${order.patient_id?.full_name?.first || ""} ${order.patient_id?.full_name?.last || ""} is now available.`,
          related_id: result._id
        });
      }
    }

    // ✅ Save notifications
    if (notifications.length > 0) {
      await Notification.insertMany(notifications);
    }

    res.status(201).json({
      message: "Result uploaded successfully",
      result,
      urgent: isUrgent
    });
  } catch (error) {
    console.error("Error uploading result:", error);
    res.status(500).json({ message: error.message });
  }
};




exports.reportInventoryIssue = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { inventory_id, issue_type, quantity, description } = req.body;

    // Validation
    if (!inventory_id || !issue_type || !quantity || quantity <= 0) {
      return res.status(400).json({
        message: "inventory_id, issue_type, and quantity (positive number) are required"
      });
    }

    if (!["damaged", "expired", "contaminated", "missing", "other"].includes(issue_type)) {
      return res.status(400).json({
        message: "Invalid issue_type. Must be: damaged, expired, contaminated, missing, or other"
      });
    }

    // Get staff to find owner_id
    const staff = await Staff.findById(staff_id);
    if (!staff) return res.status(404).json({ message: "Staff not found" });

    // Get inventory item
    const item = await Inventory.findById(inventory_id);
    if (!item) return res.status(404).json({ message: "Inventory item not found" });

    // Check ownership
    if (item.owner_id.toString() !== staff.owner_id.toString()) {
      return res.status(403).json({ message: "Cannot report issues for inventory from another lab" });
    }

    // Check if there's enough stock to report loss
    if (item.current_stock < quantity) {
      return res.status(400).json({
        message: `Cannot report loss of ${quantity} items. Only ${item.current_stock} available in stock.`
      });
    }

    // Record the loss in StockOutput
    await StockOutput.create({
      item_id: inventory_id,
      output_value: quantity,
      out_date: new Date(),
      reason: issue_type,
      staff_id: staff_id
    });

    // Update inventory count
    item.current_stock -= quantity;
    await item.save();

    // Create notification for lab owner
    const issueMessages = {
      damaged: `Damaged inventory: ${quantity} x ${item.name}`,
      expired: `Expired inventory: ${quantity} x ${item.name}`,
      contaminated: `Contaminated inventory: ${quantity} x ${item.name}`,
      missing: `Missing inventory: ${quantity} x ${item.name}`,
      other: `Inventory issue: ${quantity} x ${item.name}`
    };

    await Notification.create({
      sender_id: staff_id,
      sender_model: 'Staff',
      receiver_id: staff.owner_id,
      receiver_model: 'Owner',
      type: 'inventory',
      title: 'Inventory Issue Reported',
      message: `${issueMessages[issue_type]}\nReported by: ${staff.full_name.first} ${staff.full_name.last}\nDetails: ${description || 'No additional details provided'}\nRemaining stock: ${item.current_stock}`,
      related_id: inventory_id
    });

    // Log action
    await logAction(
      staff_id,
      staff.username,
      `Reported ${issue_type} inventory issue: ${quantity} x ${item.name}`,
      'Inventory',
      inventory_id,
      staff.owner_id
    );

    res.json({
      success: true,
      message: "Inventory issue reported successfully",
      item: {
        _id: item._id,
        name: item.name,
        remaining_stock: item.current_stock,
        quantity_reported: quantity,
        issue_type
      }
    });

  } catch (err) {
    console.error("Error reporting inventory issue:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Manually consume inventory items
 * @route   POST /api/staff/consume-inventory
 * @access  Private (Staff)
 */
exports.consumeInventory = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { inventory_id, quantity, reason } = req.body;

    // Validation
    if (!inventory_id || !quantity || quantity <= 0) {
      return res.status(400).json({
        message: "inventory_id and quantity (positive number) are required"
      });
    }

    // Get staff to find owner_id
    const staff = await Staff.findById(staff_id);
    if (!staff) return res.status(404).json({ message: "Staff not found" });

    // Get inventory item
    const item = await Inventory.findById(inventory_id);
    if (!item) return res.status(404).json({ message: "Inventory item not found" });

    // Check ownership
    if (item.owner_id.toString() !== staff.owner_id.toString()) {
      return res.status(403).json({ message: "Cannot consume inventory from another lab" });
    }

    // Check if there's enough stock
    if (item.current_stock < quantity) {
      return res.status(400).json({
        message: `Cannot consume ${quantity} items. Only ${item.current_stock} available in stock.`
      });
    }

    // Record the consumption in StockOutput
    await StockOutput.create({
      item_id: inventory_id,
      output_value: quantity,
      out_date: new Date(),
      reason: reason || 'manual_consumption',
      staff_id: staff_id
    });

    // Update inventory count
    item.current_stock -= quantity;
    await item.save();

    // Log action
    await logAction(
      staff_id,
      staff.username,
      `Consumed ${quantity} x ${item.name} (${reason || 'manual consumption'})`,
      'Inventory',
      inventory_id,
      staff.owner_id
    );

    res.json({
      success: true,
      message: "Inventory consumed successfully",
      item: {
        _id: item._id,
        name: item.name,
        remaining_stock: item.current_stock,
        quantity_consumed: quantity,
        reason: reason || 'manual_consumption'
      }
    });

  } catch (err) {
    console.error("Error consuming inventory:", err);
    res.status(500).json({ error: err.message });
  }
};

exports.getInventoryItems = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    // Get staff to find their lab
    const staff = await Staff.findById(staff_id);
    if (!staff) return res.status(404).json({ message: "Staff not found" });

    // Get total count for pagination
    const totalItems = await Inventory.countDocuments({ owner_id: staff.owner_id });

    // Get paginated inventory items - select actual fields from model
    const inventory = await Inventory.find({ owner_id: staff.owner_id })
      .select('name count critical_level item_code expiration_date')
      .sort({ name: 1 })
      .skip(skip)
      .limit(limit);

    const totalPages = Math.ceil(totalItems / limit);
    const hasMore = page < totalPages;

    res.json({
      success: true,
      data: inventory.map(item => ({
        _id: item._id,
        name: item.name,
        current_stock: item.count || 0,  // Map count to current_stock
        unit: 'units',  // Default unit since not in model
        min_threshold: item.critical_level || 0,  // Map critical_level to min_threshold
        item_code: item.item_code,
        expiration_date: item.expiration_date
      })),
      pagination: {
        currentPage: page,
        totalPages,
        totalItems,
        itemsPerPage: limit,
        hasMore
      }
    });

  } catch (err) {
    console.error("Error fetching inventory items:", err);
    res.status(500).json({ error: err.message });
  }
};



// ✅ View Assigned Tests
exports.getAssignedTests = async (req, res) => {
  try {
    const { staff_id } = req.params;
    const details = await OrderDetails.find({ staff_id })
      .populate("test_id")
      .populate("order_id");

    res.json(details);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// ✅ Collect Sample from Patient
exports.collectSample = async (req, res) => {
  try {
    const staff_id = req.user.id; // Use authenticated staff ID
    const { detail_id, notes } = req.body;

    if (!detail_id) {
      return res.status(400).json({ 
        message: "⚠️ Detail ID is required" 
      });
    }

    const detail = await OrderDetails.findById(detail_id)
      .populate({
        path: 'test_id',
        select: 'test_name sample_type tube_type device_id method',
        populate: {
          path: 'device_id',
          populate: { path: 'staff_id', select: 'full_name employee_number' }
        }
      })
      .populate('order_id');

    if (!detail) {
      return res.status(404).json({ message: "❌ Order detail not found" });
    }

    // Check if the test is assigned to this staff
    if (!detail.staff_id || detail.staff_id.toString() !== staff_id.toString()) {
      return res.status(403).json({ message: "You are not authorized to collect samples for this test" });
    }

    if (detail.sample_collected) {
      return res.status(400).json({ 
        message: "⚠️ Sample already collected for this test" 
      });
    }

    // Auto-assign staff based on test's device
    let assignedStaff = null;
    let assignedDevice = null;
    
    if (detail.test_id.method === 'device' && detail.test_id.device_id) {
      const device = detail.test_id.device_id;
      
      // Check if device is available
      if (device.status !== 'active') {
        return res.status(400).json({
          message: `⚠️ Required device (${device.name}) is currently ${device.status}. Cannot collect sample.`
        });
      }
      
      // Auto-assign to device operator
      if (device.staff_id) {
        assignedStaff = device.staff_id;
        assignedDevice = device;
        
        detail.device_id = device._id;
        detail.staff_id = device.staff_id._id;
        detail.assigned_at = new Date();
        detail.status = 'assigned';
        
        // Notify assigned staff
        await Notification.create({
          sender_id: staff_id,
          sender_model: 'Staff',
          receiver_id: device.staff_id._id,
          receiver_model: 'Staff',
          type: 'system',
          title: 'New Test Assigned',
          message: `${detail.test_id.test_name} assigned to you. Device: ${device.name}`,
          related_id: detail._id
        });
      }
    }

    // Assign order barcode to sample if not already exists
    if (!detail.barcode) {
      if (detail.order_id.barcode) {
        detail.barcode = detail.order_id.barcode;
      } else {
        // Generate barcode for order if it doesn't have one
        const Order = require('../models/Order');
        const orderBarcode = await Order.generateUniqueBarcode();
        detail.order_id.barcode = orderBarcode;
        await detail.order_id.save();
        detail.barcode = orderBarcode;
      }
    }

    // Update sample collection
    detail.sample_collected = true;
    detail.sample_collected_date = new Date();
    if (!assignedStaff) {
      detail.status = 'collected';
    }

    await detail.save();

    // Get staff username for logging
    const loggingStaff = await Staff.findById(staff_id).select('username');

    // Log action
    await logAction(
      staff_id, 
      loggingStaff.username,
      `Collected ${detail.test_id.sample_type} sample for test ${detail.test_id.test_name}`,
      'OrderDetails',
      detail_id
    );

    // Notify patient
    if (detail.order_id && detail.order_id.patient_id) {
      await Notification.create({
        sender_id: staff_id,
        sender_model: 'Staff',
        receiver_id: detail.order_id.patient_id,
        receiver_model: 'Patient',
        type: 'system',
        title: 'Sample Collected',
        message: `Your ${detail.test_id.test_name} sample has been collected and is being processed.`
      });
    }

    res.json({ 
      success: true,
      message: assignedStaff 
        ? `✅ Sample collected and assigned to ${assignedStaff.full_name.first} ${assignedStaff.full_name.last}`
        : "✅ Sample collected successfully",
      detail: {
        _id: detail._id,
        test_name: detail.test_id.test_name,
        sample_type: detail.test_id.sample_type,
        tube_type: detail.test_id.tube_type,
        sample_collected: detail.sample_collected,
        sample_collected_date: detail.sample_collected_date,
        status: detail.status,
        barcode: detail.barcode,
        assigned_staff: assignedStaff ? {
          staff_id: assignedStaff._id,
          name: `${assignedStaff.full_name.first} ${assignedStaff.full_name.last}`,
          employee_number: assignedStaff.employee_number
        } : null,
        assigned_device: assignedDevice ? {
          device_id: assignedDevice._id,
          name: assignedDevice.name,
          serial_number: assignedDevice.serial_number
        } : null,
        notes
      }
    });

  } catch (err) {
    console.error("Error collecting sample:", err);
    res.status(500).json({ error: err.message });
  }
};

// ✅ Update Sample/Test Status
exports.updateSampleStatus = async (req, res) => {
  try {
    const { detail_id, status } = req.body;

    const validStatuses = ["pending", "urgent", "collected", "in_progress", "completed"];
    if (!validStatuses.includes(status.toLowerCase())) {
      return res.status(400).json({ 
        message: `⚠️ Invalid status. Must be one of: ${validStatuses.join(', ')}` 
      });
    }

    const detail = await OrderDetails.findById(detail_id)
      .populate('test_id', 'test_name');

    if (!detail) {
      return res.status(404).json({ message: "❌ Order detail not found" });
    }

    const normalizedStatus = status.toLowerCase();
    const oldStatus = detail.status;
    
    // Prevent manual completion without result
    if (normalizedStatus === 'completed') {
      const Result = require('../models/Result');
      const result = await Result.findOne({ detail_id });
      if (!result) {
        return res.status(400).json({ 
          message: "⚠️ Cannot mark as completed without uploading result first. Please upload the test result." 
        });
      }
    }
    
    detail.status = normalizedStatus;
    
    // Auto-mark sample as collected if status is collected or beyond
    if (['collected', 'in_progress', 'completed'].includes(normalizedStatus) && !detail.sample_collected) {
      detail.sample_collected = true;
      detail.sample_collected_date = new Date();
    }

    await detail.save();
    
    // Get staff username for logging
    const loggingStaff = await Staff.findById(detail.staff_id).select('username');
    
    await logAction(
      detail.staff_id, 
      loggingStaff.username,
      `Updated test status from '${oldStatus}' to '${normalizedStatus}' for ${detail.test_id.test_name}`,
      'OrderDetails',
      detail_id
    );

    res.json({ 
      success: true,
      message: `✅ Status updated to '${normalizedStatus}'`,
      detail: {
        _id: detail._id,
        test_name: detail.test_id.test_name,
        status: detail.status,
        sample_collected: detail.sample_collected,
        sample_collected_date: detail.sample_collected_date
      }
    });

  } catch (err) {
    console.error("Error updating sample status:", err);
    res.status(500).json({ error: err.message });
  }
};



// ✅ Get Staff Assigned Devices
exports.getStaffDevices = async (req, res) => {
  try {
    const { staff_id } = req.params;

    // Verify requesting staff can access this
    if (req.user.id !== staff_id && req.user.role !== 'Owner') {
      return res.status(403).json({ message: "Access denied" });
    }

    const devices = await Device.find({ staff_id })
      .populate('assigned_tests', 'test_name')
      .sort({ name: 1 });

    res.json(devices);
  } catch (err) {
    console.error("Error fetching staff devices:", err);
    res.status(500).json({ error: err.message });
  }
};


// ✅ Get Inventory (Items Assigned or Used by Staff)
exports.getStaffInventory = async (req, res) => {
  try {
    const { staff_id } = req.params;
    const inventory = await Inventory.find({ used_by: staff_id });
    res.json(inventory);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// ✅ Get Notifications for Staff
exports.getStaffNotifications = async (req, res) => {
  try {
    const { staff_id } = req.params;
    const notifications = await Notification.find({ receiver_id: staff_id });
    res.json(notifications);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// ✅ Get all staff with last login times (for the Lab Owner Dashboard)
exports.getStaffLoginActivity = async (req, res) => {
  try {
    const { owner_id } = req.params;

    const staffList = await Staff.find({ owner_id })
      .select("full_name username email last_login login_history date_hired");

    if (!staffList.length) {
      return res.status(404).json({ message: "No staff found for this lab owner" });
    }

    res.json({
      message: "Staff login activity retrieved successfully",
      staff: staffList
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ✅ Staff Dashboard (with devices & inventory)
exports.getStaffDashboard = async (req, res) => {
  try {
    const staff_id = req.user.id; // from authMiddleware

    // 1️⃣ Assigned tests (all statuses) - Prioritize urgent tests
    const assignedTests = await OrderDetails.find({ staff_id })
      .populate('test_id', 'test_name test_code sample_type')
      .populate({
        path: 'order_id',
        select: 'barcode order_date status remarks',
        populate: { 
          path: 'patient_id', 
          select: 'full_name patient_id email phone_number' 
        }
      })
      .sort({ 
        status: 1,        // "urgent" comes before "pending" alphabetically
        createdAt: -1    // Then by newest first
      })
      .limit(20);

    // 2️⃣ Notifications
    const notifications = await Notification.find({ receiver_id: staff_id })
      .sort({ created_at: -1 })
      .limit(10);

    // 3️⃣ Recently uploaded results
    const recentResults = await Result.find({ staff_id })
      .sort({ createdAt: -1 })
      .limit(5)
      .populate("detail_id");

    // 4️⃣ Sample summary (case-insensitive status matching)
    const sampleSummary = {
      totalAssigned: assignedTests.length,
      pending: assignedTests.filter(t => t.status?.toLowerCase() === "pending").length,
      inProgress: assignedTests.filter(t => t.status?.toLowerCase() === "in progress").length,
      completed: assignedTests.filter(t => t.status?.toLowerCase() === "completed").length,
    };

    // 5️⃣ Assigned devices (check staff_id field, not assigned_to)
    const devices = await Device.find({ staff_id });

    // 6️⃣ Inventory items (if applicable)
    const inventory = await Inventory.find({ owner_id: req.user.ownerId });

    // 7️⃣ Inventory summary
    const inventorySummary = {
      totalItems: inventory.length,
      available: inventory.filter(i => i.quantity > 0).length,
      lowStock: inventory.filter(i => i.quantity <= i.min_quantity).length,
    };

    res.json({
      message: "Staff dashboard retrieved successfully",
      data: {
        sampleSummary,
        assignedTests: assignedTests.map(test => ({
          detail_id: test._id,
          test_name: test.test_id?.test_name,
          test_code: test.test_id?.test_code,
          patient: test.order_id?.patient_id ? {
            name: `${test.order_id.patient_id.full_name.first} ${test.order_id.patient_id.full_name.last}`,
            patient_id: test.order_id.patient_id.patient_id
          } : null,
          order_barcode: test.order_id?.barcode,
          status: test.status,
          sample_collected: test.sample_collected
        })),
        notifications,
        recentResults,
        devices,
        inventory,
        inventorySummary
      }
    });

  } catch (err) {
    console.error("Error fetching staff dashboard:", err);
    res.status(500).json({ error: err.message });
  }
};

// ===============================
// 📋 Pending Order Management
// ===============================

/**
 * @desc    Get all orders for the lab (all statuses)
 * @route   GET /api/staff/orders
 * @access  Private (Staff)
 */
exports.getAllLabOrders = async (req, res) => {
  try {
    const staff_id = req.user.id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Query parameters for filtering
    const { status, patient_id, startDate, endDate } = req.query;
    
    // Build query
    const query = { owner_id: staff.owner_id };
    
    if (status) {
      query.status = status;
    }
    
    if (patient_id) {
      query.patient_id = patient_id;
    }
    
    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    // Get all orders for this lab
    const orders = await Order.find(query)
      .populate('patient_id', 'full_name identity_number phone_number email')
      .sort({ order_date: -1 });

    // Get order details for each order
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code price category');
        
        const totalCost = details.reduce((sum, detail) => {
          return sum + (detail.test_id?.price || 0);
        }, 0);

        // Count completed and pending tests
        const completedTests = details.filter(d => d.status === 'completed').length;
        const pendingTests = details.filter(d => d.status === 'pending').length;

        return {
          order_id: order._id,
          barcode: order.barcode,
          patient_info: order.is_patient_registered 
            ? {
                full_name: order.patient_id?.full_name,
                identity_number: order.patient_id?.identity_number,
                phone_number: order.patient_id?.phone_number,
                email: order.patient_id?.email,
              }
            : order.temp_patient_info,
          patient_id: order.patient_id?._id,
          is_patient_registered: order.is_patient_registered,
          order_date: order.order_date,
          status: order.status,
          remarks: order.remarks,
          is_urgent: order.remarks === 'urgent',
          tests: details.map(d => ({
            test_id: d.test_id?._id,
            test_name: d.test_id?.test_name,
            test_code: d.test_id?.test_code,
            price: d.test_id?.price,
            category: d.test_id?.category,
            status: d.status,
            is_urgent: d.status === 'urgent'
          })),
          total_cost: totalCost,
          tests_count: details.length,
          completed_tests: completedTests,
          pending_tests: pendingTests
        };
      })
    );

    res.json({
      success: true,
      count: ordersWithDetails.length,
      orders: ordersWithDetails
    });

  } catch (err) {
    console.error("Error fetching lab orders:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get all pending orders (submitted but patient not registered)
 * @route   GET /api/staff/pending-orders
 * @access  Private (Staff)
 */
exports.getPendingOrders = async (req, res) => {
  try {
    const staff_id = req.user.id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Get all pending orders for this lab where patient not yet registered
    // Sort by urgency first, then by date (urgent tests appear at the top)
    const pendingOrders = await Order.find({
      owner_id: staff.owner_id,
      status: 'pending',
      is_patient_registered: false
    })
    .sort({ 
      remarks: -1,      // "urgent" > null/empty (descending = urgent first)
      order_date: 1     // Then by date (oldest first)
    });

    // Get order details for each order
    const ordersWithDetails = await Promise.all(
      pendingOrders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code price');
        
        const totalCost = details.reduce((sum, detail) => {
          return sum + (detail.test_id.price || 0);
        }, 0);

        return {
          order_id: order._id,
          barcode: order.barcode,
          patient_info: order.temp_patient_info,
          order_date: order.order_date,
          remarks: order.remarks,
          is_urgent: order.remarks === 'urgent',
          tests: details.map(d => ({
            test_name: d.test_id.test_name,
            test_code: d.test_id.test_code,
            price: d.test_id.price,
            status: d.status,
            is_urgent: d.status === 'urgent'
          })),
          total_cost: totalCost,
          tests_count: details.length
        };
      })
    );

    res.json({
      success: true,
      count: ordersWithDetails.length,
      pending_orders: ordersWithDetails
    });

  } catch (err) {
    console.error("Error fetching pending orders:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Register patient and link to existing order
 * @route   POST /api/staff/register-patient-from-order
 * @access  Private (Staff)
 */
exports.registerPatientFromOrder = async (req, res) => {
  try {
    const { order_id } = req.body;
    const staff_id = req.user.id;

    // Get the order
    const order = await Order.findById(order_id);
    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }

    if (order.is_patient_registered) {
      return res.status(400).json({ 
        message: "Patient already registered for this order" 
      });
    }

    // Check if patient already exists (by identity_number, email, or full name + phone)
    let patient = await Patient.findOne({
      $or: [
        { identity_number: order.temp_patient_info.identity_number },
        { email: order.temp_patient_info.email },
        {
          'full_name.first': order.temp_patient_info.full_name.first,
          'full_name.middle': order.temp_patient_info.full_name.middle,
          'full_name.last': order.temp_patient_info.full_name.last,
          phone_number: order.temp_patient_info.phone_number
        }
      ]
    });

    let isNewPatient = false;
    let tempPassword = null;

    // If patient doesn't exist, create new patient
    if (!patient) {
      isNewPatient = true;
      const username = order.temp_patient_info.email.split("@")[0];
      tempPassword = Math.random().toString(36).slice(-8);

      // Convert address to proper format if it's a string
      let addressData = order.temp_patient_info.address;
      if (typeof addressData === 'string') {
        const addressParts = addressData.split(',').map(part => part.trim());
        addressData = {
          street: '',
          city: addressParts[0] || '',
          country: addressParts[1] || 'Palestine'
        };
      }

      patient = await Patient.create({
        full_name: order.temp_patient_info.full_name,
        identity_number: order.temp_patient_info.identity_number,
        birthday: order.temp_patient_info.birthday,
        gender: order.temp_patient_info.gender,
        phone_number: order.temp_patient_info.phone_number,
        email: order.temp_patient_info.email,
        address: addressData,
        patient_id: `PAT-${Date.now()}`,
        username,
        password: tempPassword,
        created_by_staff: staff_id
      });

      // Send credentials email
      await sendEmail(
        patient.email,
        "Your Lab Account Has Been Created",
        `Dear ${order.temp_patient_info.full_name.first},\n\n` +
        `Your account has been created!\n\n` +
        `Username: ${username}\n` +
        `Temporary Password: ${tempPassword}\n\n` +
        `Your order (${order.barcode}) is being processed.\n` +
        `Please log in to view your results and manage your profile.\n\n` +
        `Best regards,\nLab Team`
      );
    }

    // Link patient to order
    order.patient_id = patient._id;
    order.is_patient_registered = true;
    order.status = 'processing';
    order.requested_by = staff_id;
    await order.save();

    // Get order details to create invoice and assign staff
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate({
        path: 'test_id',
        populate: {
          path: 'device_id',
          select: 'staff_id name'
        }
      });

    // 🎯 AUTO-ASSIGN STAFF BASED ON DEVICE
    for (const detail of orderDetails) {
      const test = detail.test_id;
      
      // If test uses a device and device has assigned staff
      if (test && test.method === 'device' && test.device_id && test.device_id.staff_id) {
        detail.staff_id = test.device_id.staff_id;
        await detail.save();

        // Send notification to assigned staff
        await Notification.create({
          sender_id: staff_id,
          sender_model: 'Staff',
          receiver_id: test.device_id.staff_id,
          receiver_model: 'Staff',
          type: 'system',
          title: 'New Test Assignment',
          message: `You have been assigned to perform ${test.test_name} for patient ${patient.full_name.first} ${patient.full_name.last} (Order: ${order.barcode})`
        });
      }
      // If manual test, leave staff_id null for manual assignment by owner
    }

    // Create invoice
    const subtotal = orderDetails.reduce((sum, detail) => {
      return sum + (detail.test_id.price || 0);
    }, 0);

    await Invoice.create({
      order_id: order._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'pending',
      owner_id: order.owner_id
    });

    // Send notification to patient
    await Notification.create({
      sender_id: staff_id,
      sender_model: 'Staff',
      receiver_id: patient._id,
      receiver_model: 'Patient',
      type: 'test_result',
      title: 'Order Confirmed',
      message: `Your test order (${order.barcode}) has been confirmed and is now being processed.`
    });

    // Log action
    const loggingStaff = await Staff.findById(staff_id).select('username');
    await logAction(
      staff_id,
      loggingStaff.username,
      isNewPatient 
        ? `Registered new patient ${patient.patient_id} from order ${order.barcode}`
        : `Linked existing patient ${patient.patient_id} to order ${order.barcode}`,
      'Order',
      order._id,
      order.owner_id
    );

    res.json({
      success: true,
      message: isNewPatient 
        ? "✅ New patient registered and order linked!"
        : "✅ Existing patient found and order linked!",
      patient: {
        _id: patient._id,
        patient_id: patient.patient_id,
        name: `${patient.full_name.first} ${patient.full_name.last}`,
        email: patient.email,
        is_new: isNewPatient,
        credentials: isNewPatient ? {
          username: patient.username,
          temp_password: tempPassword
        } : null
      },
      order: {
        _id: order._id,
        barcode: order.barcode,
        status: order.status,
        total_amount: subtotal
      }
    });

  } catch (err) {
    console.error("Error registering patient from order:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get all unassigned tests (tests without staff assignment)
 * @route   GET /api/staff/unassigned-tests
 * @access  Owner/Manager
 */
exports.getUnassignedTests = async (req, res) => {
  try {
    const owner_id = req.user.ownerId; // Assuming owner is logged in

    // Find all order details where staff_id is null and order belongs to this lab
    // Sort by urgency first (urgent tests at the top)
    const unassignedTests = await OrderDetails.find({ 
      staff_id: null 
    })
    .populate({
      path: 'order_id',
      match: { owner_id: owner_id },
      populate: { path: 'patient_id', select: 'full_name patient_id' }
    })
    .populate('test_id', 'test_name test_code method sample_type')
    .sort({ 
      status: 1,        // "urgent" before "pending" alphabetically
      createdAt: -1    // Then by newest first
    })
    .lean();

    // Filter out tests where order doesn't belong to this lab
    const filteredTests = unassignedTests.filter(test => test.order_id !== null);

    res.json({
      success: true,
      count: filteredTests.length,
      unassigned_tests: filteredTests.map(test => ({
        detail_id: test._id,
        test_name: test.test_id?.test_name,
        test_code: test.test_id?.test_code,
        method: test.test_id?.method,
        sample_type: test.test_id?.sample_type,
        status: test.status,
        patient_name: test.order_id?.patient_id 
          ? `${test.order_id.patient_id.full_name.first} ${test.order_id.patient_id.full_name.last}`
          : 'Unknown',
        patient_id: test.order_id?.patient_id?.patient_id,
        order_barcode: test.order_id?.barcode,
        order_status: test.order_id?.status
      }))
    });

  } catch (err) {
    console.error("Error fetching unassigned tests:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Manually assign staff to a test (for manual tests or reassignment)
 * @route   POST /api/staff/assign-to-test
 * @access  Owner/Manager
 */
exports.assignStaffToTest = async (req, res) => {
  try {
    const { detail_id, staff_id } = req.body;

    if (!detail_id || !staff_id) {
      return res.status(400).json({ 
        message: "detail_id and staff_id are required" 
      });
    }

    // Get order detail with test and order info
    const detail = await OrderDetails.findById(detail_id)
      .populate('test_id', 'test_name')
      .populate({
        path: 'order_id',
        populate: { path: 'patient_id', select: 'full_name' }
      });

    if (!detail) {
      return res.status(404).json({ message: "Order detail not found" });
    }

    // Verify staff exists and belongs to same lab
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Verify staff belongs to same lab as the order
    if (staff.owner_id.toString() !== detail.order_id.owner_id.toString()) {
      return res.status(403).json({ message: "Cannot assign staff from different lab" });
    }

    // Update assignment
    const previousStaffId = detail.staff_id;
    detail.staff_id = staff_id;
    await detail.save();

    // Send notification to newly assigned staff
    await Notification.create({
      sender_id: req.user.id,
      sender_model: 'Owner',
      receiver_id: staff_id,
      receiver_model: 'Staff',
      type: 'system',
      title: previousStaffId ? 'Test Reassigned to You' : 'New Test Assignment',
      message: `You have been assigned to perform ${detail.test_id.test_name} for patient ${detail.order_id.patient_id?.full_name.first || 'Unknown'} (Order: ${detail.order_id.barcode})`
    });

    // If reassignment, notify previous staff
    if (previousStaffId && previousStaffId.toString() !== staff_id.toString()) {
      await Notification.create({
        sender_id: req.user.id,
        sender_model: 'Owner',
        receiver_id: previousStaffId,
        receiver_model: 'Staff',
        type: 'system',
        title: 'Test Reassigned',
        message: `Test ${detail.test_id.test_name} (Order: ${detail.order_id.barcode}) has been reassigned to another staff member`
      });
    }

    // Log action
    const LabOwner = require('../models/Owner');
    const loggingOwner = await LabOwner.findById(req.user.id).select('username');
    await logAction(
      req.user.id,
      loggingOwner.username,
      previousStaffId 
        ? `Reassigned test ${detail.test_id.test_name} from staff ${previousStaffId} to ${staff_id}`
        : `Assigned test ${detail.test_id.test_name} to staff ${staff_id}`,
      'OrderDetails',
      detail._id,
      detail.order_id.owner_id
    );

    res.json({
      success: true,
      message: previousStaffId ? "✅ Test reassigned successfully" : "✅ Staff assigned successfully",
      detail: {
        detail_id: detail._id,
        test_name: detail.test_id.test_name,
        assigned_to: {
          staff_id: staff._id,
          staff_name: `${staff.full_name.first} ${staff.full_name.last}`
        }
      }
    });

  } catch (err) {
    console.error("Error assigning staff to test:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get order details (test items) for a specific order
 * @route   GET /api/staff/order-details/:order_id
 * @access  Staff (Auth Required)
 */
exports.getOrderDetails = async (req, res) => {
  try {
    const { order_id } = req.params;

    const orderDetails = await OrderDetails.find({ order_id })
      .populate('test_id', 'test_name test_code sample_type price device_id')
      .populate('order_id', 'barcode status')
      .populate('staff_id', 'full_name employee_number')
      .populate({
        path: 'test_id',
        populate: {
          path: 'device_id',
          select: 'name serial_number'
        }
      })
      .lean();

    if (!orderDetails || orderDetails.length === 0) {
      return res.status(404).json({ message: "No order details found for this order" });
    }

    res.json({
      success: true,
      count: orderDetails.length,
      order_details: orderDetails.map(detail => ({
        detail_id: detail._id,
        test_name: detail.test_id?.test_name,
        test_code: detail.test_id?.test_code,
        sample_type: detail.test_id?.sample_type,
        price: detail.test_id?.price,
        device: detail.test_id?.device_id ? {
          name: detail.test_id.device_id.name,
          serial_number: detail.test_id.device_id.serial_number
        } : null,
        assigned_staff: detail.staff_id ? {
          _id: detail.staff_id._id,
          name: `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}`,
          employee_number: detail.staff_id.employee_number
        } : null,
        status: detail.status,
        sample_collected: detail.sample_collected,
        sample_collected_date: detail.sample_collected_date,
        order_barcode: detail.order_id?.barcode,
        order_status: detail.order_id?.status
      }))
    });

  } catch (err) {
    console.error("Error fetching order details:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Mark test as completed (for tests that have results uploaded)
 * @route   PUT /api/staff/mark-completed/:detail_id
 * @access  Staff/Owner
 */
exports.markTestCompleted = async (req, res) => {
  try {
    const { detail_id } = req.params;

    const detail = await OrderDetails.findById(detail_id);
    if (!detail) {
      return res.status(404).json({ message: "Order detail not found" });
    }

    // Check if result exists
    const result = await Result.findOne({ detail_id });
    if (!result) {
      return res.status(400).json({ message: "Cannot mark as completed - no result uploaded yet" });
    }

    // Update status
    detail.status = 'completed';
    await detail.save();

    res.json({
      success: true,
      message: "Test marked as completed",
      detail_id: detail._id,
      status: detail.status
    });

  } catch (err) {
    console.error("Error marking test as completed:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Generate barcode for a sample/test (can be called before sample collection)
 * @route   POST /api/staff/generate-sample-barcode/:detail_id
 * @access  Private (Staff)
 */
exports.generateSampleBarcode = async (req, res) => {
  try {
    const { detail_id } = req.params;
    const { frontend_barcode } = req.body;
    const staff_id = req.user.id;

    const OrderDetails = require('../models/OrderDetails');

    const detail = await OrderDetails.findById(detail_id).populate('order_id');
    if (!detail) {
      return res.status(404).json({ message: "Order detail not found" });
    }

    // Check if staff has access to this test
    if (detail.staff_id && detail.staff_id.toString() !== staff_id) {
      return res.status(403).json({ message: "Access denied - test not assigned to you" });
    }

    let barcode;

    if (frontend_barcode) {
      // Use frontend-generated barcode
      try {
        barcode = await OrderDetails.validateAndSetSampleBarcode(detail_id, frontend_barcode);
      } catch (error) {
        return res.status(400).json({ message: error.message });
      }
    } else {
      // Generate barcode on backend
      if (detail.barcode) {
        return res.status(400).json({ message: "Sample already has a barcode" });
      }
      barcode = await OrderDetails.generateUniqueSampleBarcode();
      await OrderDetails.findByIdAndUpdate(detail_id, { barcode });
    }

    // Update order status to processing if not already
    if (detail.order_id.status === 'pending') {
      await require('../models/Order').findByIdAndUpdate(detail.order_id._id, { status: 'processing' });
    }

    res.json({
      success: true,
      message: "Sample barcode generated successfully",
      barcode: barcode,
      detail_id: detail_id,
      order_id: detail.order_id._id
    });

  } catch (err) {
    console.error("Error generating sample barcode:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Generate barcode for an order (can be called before sample collection)
 * @route   POST /api/staff/generate-barcode/:order_id
 * @access  Private (Staff)
 */
exports.generateBarcode = async (req, res) => {
  try {
    const { order_id } = req.params;
    const { frontend_barcode } = req.body;

    const order = await Order.findById(order_id);
    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }

    let barcode;

    if (frontend_barcode) {
      // Use frontend-generated barcode
      try {
        barcode = await Order.validateAndSetBarcode(order_id, frontend_barcode);
      } catch (error) {
        return res.status(400).json({ message: error.message });
      }
    } else {
      // Generate barcode on backend
      if (order.barcode) {
        return res.status(400).json({ message: "Order already has a barcode" });
      }
      barcode = await Order.generateUniqueBarcode();
      await Order.findByIdAndUpdate(order_id, { barcode });
    }

    // Update order status to processing if not already
    if (order.status === 'pending') {
      await Order.findByIdAndUpdate(order_id, { status: 'processing' });
    }

    res.json({
      success: true,
      message: "Barcode generated successfully",
      barcode: barcode,
      order_id: order_id
    });

  } catch (err) {
    console.error("Error generating barcode:", err);
    res.status(500).json({ error: err.message });
  }
};
exports.getMyAssignedTests = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { status_filter, device_id } = req.query;

    // Build query
    let query = { staff_id };
    if (status_filter) {
      query.status = status_filter;
    }
    if (device_id) {
      query.device_id = device_id;
    }

    // Find all order details assigned to this staff member
    const assignedTests = await OrderDetails.find(query)
      .populate({
        path: 'test_id',
        select: 'test_name test_code sample_type device_id method',
        populate: {
          path: 'device_id',
          select: 'name serial_number status'
        }
      })
      .populate({
        path: 'order_id',
        select: 'barcode order_date status patient_id remarks',
        populate: {
          path: 'patient_id',
          select: 'full_name patient_id phone_number'
        }
      })
      .populate('device_id', 'name serial_number status')
      .populate('staff_id', 'full_name employee_number')
      .sort({ 
        status: 1,
        assigned_at: -1
      })
      .lean();

    // Group tests by status
    const statusGroups = {
      urgent: [],
      assigned: [],
      collected: [],
      in_progress: [],
      completed: []
    };

    // Get unique devices
    const devices = new Set();

    assignedTests.forEach(detail => {
      const isUrgent = detail.status === 'urgent' || detail.order_id?.remarks === 'urgent';
      
      const testData = {
        detail_id: detail._id,
        test_name: detail.test_id?.test_name,
        test_code: detail.test_id?.test_code,
        sample_type: detail.test_id?.sample_type,
        device: detail.device_id || detail.test_id?.device_id ? {
          device_id: (detail.device_id || detail.test_id?.device_id)?._id,
          name: (detail.device_id || detail.test_id?.device_id)?.name,
          serial_number: (detail.device_id || detail.test_id?.device_id)?.serial_number,
          status: (detail.device_id || detail.test_id?.device_id)?.status
        } : null,
        patient: detail.order_id?.patient_id ? {
          name: `${detail.order_id.patient_id.full_name.first} ${detail.order_id.patient_id.full_name.last}`,
          patient_id: detail.order_id.patient_id.patient_id,
          phone: detail.order_id.patient_id.phone_number
        } : null,
        order_barcode: detail.order_id?.barcode,
        order_date: detail.order_id?.order_date,
        status: detail.status,
        is_urgent: isUrgent,
        sample_collected: detail.sample_collected,
        sample_collected_date: detail.sample_collected_date,
        assigned_at: detail.assigned_at,
        result_uploaded: detail.result_id ? true : false
      };

      // Add to device set
      if (testData.device?.device_id) {
        devices.add(JSON.stringify(testData.device));
      }

      // Group by status
      if (isUrgent && detail.status !== 'completed') {
        statusGroups.urgent.push(testData);
      } else {
        statusGroups[detail.status]?.push(testData);
      }
    });

    // Calculate statistics
    const stats = {
      total: assignedTests.length,
      urgent: statusGroups.urgent.length,
      assigned: statusGroups.assigned.length,
      collected: statusGroups.collected.length,
      in_progress: statusGroups.in_progress.length,
      completed: statusGroups.completed.length,
      pending_work: statusGroups.assigned.length + statusGroups.collected.length + statusGroups.in_progress.length + statusGroups.urgent.length
    };

    res.json({
      success: true,
      stats,
      devices: Array.from(devices).map(d => JSON.parse(d)),
      tests_by_status: statusGroups,
      all_tests: assignedTests.map(detail => ({
        detail_id: detail._id,
        test_name: detail.test_id?.test_name,
        test_code: detail.test_id?.test_code,
        sample_type: detail.test_id?.sample_type,
        device: detail.device_id || detail.test_id?.device_id ? {
          name: (detail.device_id || detail.test_id?.device_id)?.name,
          serial_number: (detail.device_id || detail.test_id?.device_id)?.serial_number
        } : null,
        patient: detail.order_id?.patient_id ? {
          name: `${detail.order_id.patient_id.full_name.first} ${detail.order_id.patient_id.full_name.last}`,
          patient_id: detail.order_id.patient_id.patient_id
        } : null,
        order_barcode: detail.order_id?.barcode,
        status: detail.status,
        is_urgent: detail.status === 'urgent' || detail.order_id?.remarks === 'urgent',
        sample_collected: detail.sample_collected,
        assigned_at: detail.assigned_at
      }))
    });

  } catch (err) {
    console.error("Error fetching assigned tests:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Auto-assign tests based on device-staff relationship (bulk operation)
 * @route   POST /api/staff/auto-assign-tests
 * @access  Staff (Auth Required)
 */
exports.autoAssignTests = async (req, res) => {
  try {
    const { order_id } = req.body;
    const staff_id = req.user.id;

    if (!order_id) {
      return res.status(400).json({ message: "order_id is required" });
    }

    // Get all order details for this order
    const orderDetails = await OrderDetails.find({ 
      order_id,
      sample_collected: true,
      staff_id: null  // Not yet assigned
    }).populate({
      path: 'test_id',
      populate: {
        path: 'device_id',
        populate: { path: 'staff_id' }
      }
    });

    if (orderDetails.length === 0) {
      return res.status(404).json({ 
        message: "No unassigned tests found for this order" 
      });
    }

    const assignments = [];
    const notifications = [];

    for (const detail of orderDetails) {
      if (detail.test_id.method === 'device' && detail.test_id.device_id) {
        const device = detail.test_id.device_id;
        
        // Check if device is available
        if (device.status !== 'active') {
          assignments.push({
            detail_id: detail._id,
            test_name: detail.test_id.test_name,
            status: 'skipped',
            reason: `Device ${device.name} is ${device.status}`
          });
          continue;
        }

        // Check if device has assigned staff
        if (!device.staff_id) {
          assignments.push({
            detail_id: detail._id,
            test_name: detail.test_id.test_name,
            status: 'skipped',
            reason: `No staff assigned to device ${device.name}`
          });
          continue;
        }

        // Assign to device operator
        detail.device_id = device._id;
        detail.staff_id = device.staff_id._id;
        detail.assigned_at = new Date();
        detail.status = 'assigned';
        await detail.save();

        assignments.push({
          detail_id: detail._id,
          test_name: detail.test_id.test_name,
          status: 'assigned',
          assigned_to: {
            staff_id: device.staff_id._id,
            name: `${device.staff_id.full_name.first} ${device.staff_id.full_name.last}`
          },
          device: {
            device_id: device._id,
            name: device.name
          }
        });

        // Create notification for assigned staff
        notifications.push({
          sender_id: staff_id,
          sender_model: 'Staff',
          receiver_id: device.staff_id._id,
          receiver_model: 'Staff',
          type: 'system',
          title: 'New Test Assigned',
          message: `${detail.test_id.test_name} assigned to you. Device: ${device.name}`,
          related_id: detail._id
        });
      } else if (detail.test_id.method === 'manual') {
        // Manual tests don't need device assignment
        assignments.push({
          detail_id: detail._id,
          test_name: detail.test_id.test_name,
          status: 'manual',
          reason: 'Manual test - no device required'
        });
      }
    }

    // Send all notifications
    if (notifications.length > 0) {
      await Notification.insertMany(notifications);
    }

    // Log action
    const loggingStaff = await Staff.findById(staff_id).select('username');
    await logAction(
      staff_id,
      loggingStaff.username,
      `Auto-assigned ${assignments.filter(a => a.status === 'assigned').length} tests for order ${order_id}`,
      'Order',
      order_id
    );

    res.json({
      success: true,
      message: `✅ ${assignments.filter(a => a.status === 'assigned').length} tests assigned successfully`,
      assignments,
      stats: {
        total: assignments.length,
        assigned: assignments.filter(a => a.status === 'assigned').length,
        skipped: assignments.filter(a => a.status === 'skipped').length,
        manual: assignments.filter(a => a.status === 'manual').length
      }
    });

  } catch (err) {
    console.error("Error auto-assigning tests:", err);
    res.status(500).json({ error: err.message });
  }
};

// ==================== FEEDBACK ====================

/**
 * @desc    Provide Feedback on Lab, Test, or Order
 * @route   POST /api/staff/feedback
 * @access  Private (Staff)
 */
exports.provideFeedback = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { target_type, target_id, rating, message, is_anonymous } = req.body;

    // Validate required fields
    if (!target_type || !rating) {
      return res.status(400).json({ message: '⚠️ Target type and rating are required' });
    }

    // Validate target_type
    const validTargetTypes = ['lab', 'test', 'order', 'system'];
    if (!validTargetTypes.includes(target_type)) {
      return res.status(400).json({ message: '⚠️ Invalid target type. Must be lab, test, order, or system' });
    }

    // For non-system feedback, target_id is required
    if (target_type !== 'system' && !target_id) {
      return res.status(400).json({ message: '⚠️ Target ID is required for non-system feedback' });
    }

    // Validate rating (1-5)
    if (rating < 1 || rating > 5) {
      return res.status(400).json({ message: '⚠️ Rating must be between 1 and 5' });
    }

    // Get staff to find their lab
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: 'Staff not found' });
    }

    // Validate target exists and staff has access (skip for system feedback)
    let targetExists = target_type === 'system';
    let targetOwnerId = null;

    if (target_type !== 'system') {
      switch (target_type) {
        case 'lab':
          const Owner = require('../models/Owner');
          const lab = await Owner.findById(target_id);
          if (lab && lab._id.toString() === staff.owner_id.toString()) {
            targetExists = true;
            targetOwnerId = lab._id;
          }
          break;
        case 'test':
          const test = await Test.findById(target_id);
          if (test && test.owner_id.toString() === staff.owner_id.toString()) {
            targetExists = true;
            targetOwnerId = test.owner_id;
          }
          break;
        case 'order':
          const order = await Order.findOne({
            _id: target_id,
            owner_id: staff.owner_id
          });
          if (order) {
            targetExists = true;
            targetOwnerId = order.owner_id;
          }
          break;
      }

      if (!targetExists) {
        return res.status(404).json({ message: '❌ Target not found or access denied' });
      }
    }

    // Create feedback
    const feedback = new Feedback({
      user_id: staff_id,
      user_model: 'Staff',
      target_type,
      target_id: target_type === 'system' ? null : target_id,
      rating,
      message: message || '',
      is_anonymous: is_anonymous || false
    });

    await feedback.save();

    // Send notification to lab owner (skip for system feedback)
    if (targetOwnerId) {
      await Notification.create({
        sender_id: staff_id,
        sender_model: 'Staff',
        receiver_id: targetOwnerId,
        receiver_model: 'Owner',
        type: 'feedback',
        title: '⭐ New Feedback Received',
        message: `Staff member ${staff.full_name.first} ${staff.full_name.last} provided ${rating}-star feedback on your ${target_type}`
      });
    }

    res.status(201).json({
      message: '✅ Feedback submitted successfully',
      feedback: {
        _id: feedback._id,
        rating: feedback.rating,
        message: feedback.message,
        is_anonymous: feedback.is_anonymous,
        createdAt: feedback.createdAt
      }
    });
  } catch (err) {
    console.error("Error providing feedback:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get My Feedback History
 * @route   GET /api/staff/feedback
 * @access  Private (Staff)
 */
exports.getMyFeedback = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { page = 1, limit = 10, target_type } = req.query;

    const query = {
      user_id: staff_id,
      user_model: 'Staff'
    };

    if (target_type) {
      query.target_type = target_type;
    }

    const feedback = await Feedback.find(query)
      .populate({
        path: 'target_id',
        select: 'name lab_name test_name barcode',
        model: function(doc) {
          switch (doc.target_type) {
            case 'lab': return 'Owner';
            case 'test': return 'Test';
            case 'order': return 'Order';
            case 'system': return null; // System feedback has no specific target
            default: return null;
          }
        }
      })
      .sort({ createdAt: -1 })
      .limit(limit * 1)
      .skip((page - 1) * limit);

    const total = await Feedback.countDocuments(query);

    res.json({
      success: true,
      feedbacks: feedback,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (err) {
    console.error("Error fetching feedback:", err);
    res.status(500).json({ error: err.message });
  }
};

// ==================== MISSING FUNCTIONS ====================

/**
 * @desc    Report an issue with a device
 * @route   POST /api/staff/report-issue
 * @access  Private (Staff)
 */
exports.reportIssue = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { device_id, issue_description } = req.body;

    if (!device_id || !issue_description) {
      return res.status(400).json({ message: "Device ID and issue description are required" });
    }

    // Verify device exists and belongs to staff's lab
    const device = await Device.findById(device_id);
    if (!device) {
      return res.status(404).json({ message: "Device not found" });
    }

    const staff = await Staff.findById(staff_id);
    if (device.owner_id.toString() !== staff.owner_id.toString()) {
      return res.status(403).json({ message: "Cannot report issue for device from another lab" });
    }

    // Create notification for lab owner
    await Notification.create({
      sender_id: staff_id,
      sender_model: 'Staff',
      receiver_id: staff.owner_id,
      receiver_model: 'Owner',
      type: 'issue',
      title: 'Device Issue Reported',
      message: `Staff reported issue with device ${device.name}: ${issue_description}`
    });

    res.json({ message: "Issue reported successfully" });
  } catch (err) {
    console.error("Error reporting issue:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get devices assigned to staff
 * @route   GET /api/staff/devices/:staff_id
 * @access  Private (Staff)
 */
exports.getStaffDevices = async (req, res) => {
  try {
    const { staff_id } = req.params;

    // Verify requesting staff can access this
    if (req.user.id !== staff_id && req.user.role !== 'Owner') {
      return res.status(403).json({ message: "Access denied" });
    }

    const devices = await Device.find({ staff_id })
      .populate('assigned_tests', 'test_name')
      .sort({ name: 1 });

    res.json(devices);
  } catch (err) {
    console.error("Error fetching staff devices:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Report an inventory issue
 * @route   POST /api/staff/report-inventory-issue
 * @access  Private (Staff)
 */
exports.reportInventoryIssue = async (req, res) => {
  try {
    const staff_id = req.user.id;
    const { item_id, issue_description } = req.body;

    if (!item_id || !issue_description) {
      return res.status(400).json({ message: "Item ID and issue description are required" });
    }

    // Verify item exists and belongs to staff's lab
    const item = await Inventory.findById(item_id);
    if (!item) {
      return res.status(404).json({ message: "Inventory item not found" });
    }

    const staff = await Staff.findById(staff_id);
    if (item.owner_id.toString() !== staff.owner_id.toString()) {
      return res.status(403).json({ message: "Cannot report issue for item from another lab" });
    }

    // Create notification for lab owner
    await Notification.create({
      sender_id: staff_id,
      sender_model: 'Staff',
      receiver_id: staff.owner_id,
      receiver_model: 'Owner',
      type: 'issue',
      title: 'Inventory Issue Reported',
      message: `Staff reported issue with inventory item ${item.name}: ${issue_description}`
    });

    res.json({ message: "Inventory issue reported successfully" });
  } catch (err) {
    console.error("Error reporting inventory issue:", err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = exports;
