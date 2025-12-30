const Staff = require("../models/Staff");

// ==================== PROFILE MANAGEMENT ====================

/**
 * @desc    Get Staff Profile
 * @route   GET /api/staff/profile
 * @access  Private (Staff)
 */
exports.getProfile = async (req, res, next) => {
  try {
    const staff = await Staff.findById(req.user._id)
      .select('-password')
      .populate('owner_id', 'lab_name email phone_number');
    
    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    res.json(staff);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Change Staff Password
 * @route   PUT /api/staff/change-password
 * @access  Private (Staff)
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // Validate input
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: '⚠️ New password must be at least 6 characters long' });
    }

    // Find staff member
    const staff = await Staff.findById(req.user._id);
    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    // Verify current password
    const isMatch = await staff.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Current password is incorrect' });
    }

    // Update password
    staff.password = newPassword;
    await staff.save();

    res.json({ message: '✅ Password changed successfully' });
  } catch (err) {
    next(err);
  }
};
exports.updateProfile = async (req, res, next) => {
  try {
    const {
      name,
      phone_number,
      email,
      address
    } = req.body;

    const staff = await Staff.findById(req.user._id);
    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    // Update allowed fields
    if (name) staff.name = name;
    if (phone_number) staff.phone_number = phone_number;
    if (email) staff.email = email;
    if (address) {
      if (typeof address === 'string') {
        const addressParts = address.split(',').map(part => part.trim());
        staff.address = {
          street: addressParts[0] || '',
          city: addressParts[1] || '',
          country: addressParts[2] || 'Palestine'
        };
      } else {
        staff.address = {
          street: address.street || '',
          city: address.city || '',
          country: address.country || 'Palestine'
        };
      }
    }

    await staff.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      staff: await Staff.findById(staff._id).select('-password').populate('owner_id', 'lab_name email phone_number')
    });
  } catch (err) {
    next(err);
  }
};
const Patient = require("../models/Patient");
const Order = require("../models/Order");
const Test = require("../models/Test");
const TestComponent = require("../models/TestComponent");
const OrderDetails = require("../models/OrderDetails");
const Result = require("../models/Result");
const ResultComponent = require("../models/ResultComponent");
const Invoice = require("../models/Invoices");
const { Inventory } = require("../models/Inventory");
const { StockOutput } = require("../models/Inventory");
const Device = require("../models/Device");
const Notification = require("../models/Notification");
const Feedback = require("../models/Feedback");
const LabOwner = require("../models/Owner");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const sendEmail = require("../utils/sendEmail");
const { sendWhatsAppMessage } = require("../utils/sendWhatsApp");
const { sendLabReport, sendAccountActivation, sendInvoiceReport } = require("../utils/sendNotification");
const logAction = require("../utils/logAction");


/**
 * @desc    Get all tests available in the staff's lab
 * @route   GET /api/staff/lab-tests
 * @access  Private (Staff)
 */
exports.getLabTests = async (req, res) => {
  try {
    const staff_id = req.user._id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Get all tests for this lab
    const tests = await Test.find({ owner_id: staff.owner_id })
      .select('test_name test_code price category description units reference_range')
      .sort({ test_name: 1 });
    
    // console.log('tests found:', tests.length);

    res.json({
      success: true,
      count: tests.length,
      tests
    });

  } catch (err) {
    console.error("Error fetching lab tests:", err);
    res.status(500).json({ error: err.message });
  }
};

// ✅ Staff Login (with login history + logging)
exports.loginStaff = async (req, res) => {
  try {
    const { username, password } = req.body;

    const staff = await Staff.findOne({ $or: [{ username }, { email: username }] });

    if (!staff || !(await staff.comparePassword(password))) {
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
    const staff_id = req.user._id; // Use authenticated staff ID
    const { detail_id, result_value, remarks, components } = req.body;

    // Validate required fields
    if (!detail_id) {
      return res.status(400).json({ message: "detail_id is required" });
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

    // 2️⃣ Check if this test has components
    const testComponents = await TestComponent.find({ 
      test_id: test._id, 
      is_active: true 
    }).sort({ display_order: 1, createdAt: 1 });

    const hasComponents = testComponents.length > 0;

    // Validate data based on test type
    if (hasComponents) {
      if (!components || !Array.isArray(components) || components.length === 0) {
        return res.status(400).json({ 
          message: "This test requires component values",
          components: testComponents.map(c => ({
            component_id: c._id,
            component_name: c.component_name,
            component_code: c.component_code,
            units: c.units,
            reference_range: c.reference_range
          }))
        });
      }
    } else {
      if (!result_value) {
        return res.status(400).json({ message: "result_value is required for single-value tests" });
      }
    }

    // 3️⃣ Initialize abnormality flags
    let isAbnormal = false;
    let abnormalComponentsCount = 0;

    // 4️⃣ Save result (main record)
    const result = await Result.create({
      detail_id,
      staff_id,
      has_components: hasComponents,
      result_value: hasComponents ? null : result_value,
      units: hasComponents ? null : test.units,
      reference_range: hasComponents ? null : test.reference_range,
      remarks,
      is_abnormal: false, // Will be updated after component analysis
      abnormal_components_count: 0
    });

    // 5️⃣ Handle components if present
    if (hasComponents) {
      const resultComponents = [];
      
      for (const comp of components) {
        const testComponent = testComponents.find(tc => tc._id.toString() === comp.component_id);
        if (!testComponent) {
          continue; // Skip unknown components
        }

        // Check if component value is abnormal
        let isComponentAbnormal = false;
        if (testComponent.reference_range) {
          const rangeMatch = testComponent.reference_range.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)/);
          if (rangeMatch) {
            const min = parseFloat(rangeMatch[1]);
            const max = parseFloat(rangeMatch[2]);
            const value = parseFloat(comp.component_value);
            if (!isNaN(value) && (value < min || value > max)) {
              isComponentAbnormal = true;
              isAbnormal = true;
              abnormalComponentsCount++;
            }
          }
        }

        resultComponents.push({
          result_id: result._id,
          component_id: testComponent._id,
          component_name: testComponent.component_name,
          component_value: comp.component_value,
          units: testComponent.units,
          reference_range: testComponent.reference_range,
          is_abnormal: isAbnormal,
          remarks: comp.remarks || null
        });
      }

      // Save all component results
      if (resultComponents.length > 0) {
        await ResultComponent.insertMany(resultComponents);
      }
    } else {
      // Single-value test: Check if result is outside normal range
      if (test.reference_range && typeof test.reference_range === "string") {
        const rangeMatch = test.reference_range.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)/);
        if (rangeMatch) {
          const min = parseFloat(rangeMatch[1]);
          const max = parseFloat(rangeMatch[2]);
          const resultNum = parseFloat(result_value);
          if (!isNaN(resultNum) && (resultNum < min || resultNum > max)) {
            isAbnormal = true;
            abnormalComponentsCount = 1; // Single abnormal value
          }
        }
      }
    }

    // Update result with abnormality information
    result.is_abnormal = isAbnormal;
    result.abnormal_components_count = abnormalComponentsCount;
    await result.save();

    // 6️⃣ Update OrderDetails status to 'completed' and link result
    detail.status = 'completed';
    detail.result_id = result._id;
    await detail.save();

    // 7️⃣ Send notifications
    const notifications = [];

    // 🔔 To the Patient (result available)
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
        message: `Test ${test.test_name} result for patient ${order.patient_id?.full_name?.first || ''} ${order.patient_id?.full_name?.last || ''} is now available.`,
        related_id: result._id
      });
    }

    // ✅ Save notifications
    if (notifications.length > 0) {
      await Notification.insertMany(notifications);
    }

    // 📱 Send notification to patient if result is ready (both WhatsApp and Email)
    if (order.patient_id && order.patient_id.phone_number && order.patient_id.email) {
      try {
        const patientName = `${order.patient_id.full_name?.first || ''} ${order.patient_id.full_name?.last || ''}`.trim();
        const resultUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/patient-dashboard/order-report/${order._id}`;
        
        // Populate result with components if it has them
        if (hasComponents) {
          const resultComponents = await ResultComponent.find({ result_id: result._id })
            .populate('component_id')
            .sort({ createdAt: 1 });
          
          result.components = resultComponents.map(rc => ({
            component_name: rc.component_id.component_name,
            component_code: rc.component_id.component_code,
            result_value: rc.component_value,
            units: rc.units,
            reference_range: rc.reference_range,
            is_abnormal: rc.is_abnormal,
            remarks: rc.remarks
          }));
        }
        
        // Send both WhatsApp and Email notifications with abnormality info
        const notificationSuccess = await sendLabReport(
          order.patient_id,
          test,
          resultUrl,
          order.owner_id?.lab_name || 'Medical Lab',
          detail._id,
          isAbnormal,
          abnormalComponentsCount,
          order,
          result,
          detail
        );

        if (notificationSuccess) {
          // console.log(`Lab report notification sent to patient ${patientName} for test ${test.test_name} via WhatsApp and Email${isAbnormal ? ' (ABNORMAL RESULTS)' : ''}`);
        }
      } catch (whatsappError) {
        console.error('Failed to send notification:', whatsappError);
        // Continue with the response - don't fail the upload
      }
    }

    // 🔍 Check if all tests in this order are completed and update order status
    try {
      const allOrderDetails = await OrderDetails.find({ order_id: order._id });
      const totalTests = allOrderDetails.length;
      const completedTests = allOrderDetails.filter(detail => detail.status === 'completed').length;
      
      // If all tests are completed, mark the order as completed
      if (totalTests > 0 && completedTests === totalTests && order.status !== 'completed') {
        order.status = 'completed';
        await order.save();
        // console.log(`Order ${order._id} marked as completed - all ${totalTests} tests are done`);
      }
    } catch (orderCheckError) {
      console.error('Error checking order completion:', orderCheckError);
      // Don't fail the response for this
    }

    res.status(201).json({
      success: true,
      message: "Result uploaded successfully",
      result,
      has_components: hasComponents
    });
  } catch (error) {
    console.error("Error uploading result:", error);
    res.status(500).json({ message: error.message });
  }
};

/**
 * @desc    Run Test with HL7 Simulation
 * @route   POST /api/staff/run-test
 * @access  Private (Staff)
 */
exports.runTest = async (req, res) => {
  try {
    // console.log('🎯 BACKEND SIMULATION START: runTest endpoint called');
    // console.log('📨 BACKEND: Request body:', req.body);

    // For testing without auth, use detail.staff_id
    const staff_id = req.user ? req.user._id : null;
    const { detail_id, priority = 'normal' } = req.body;

    // console.log('👤 BACKEND: Staff ID:', staff_id);
    // console.log('🆔 BACKEND: Detail ID:', detail_id);
    // console.log('🔥 BACKEND: Priority:', priority);

    // Validate required fields
    if (!detail_id) {
      // console.log('❌ BACKEND: Validation failed - detail_id is required');
      return res.status(400).json({ message: "detail_id is required" });
    }

    // console.log('✅ BACKEND SIMULATION STEP 1: Validation passed, loading order detail');

    // 1️⃣ Load order detail with related test + order + patient
    const detail = await OrderDetails.findById(detail_id)
      .populate("test_id")
      .populate({
        path: "order_id",
        populate: [{ path: "patient_id" }]
      });

    if (!detail) {
      // console.log('❌ BACKEND: Order detail not found for ID:', detail_id);
      return res.status(404).json({ message: "Order detail not found" });
    }

    // console.log('📋 BACKEND: Order detail loaded successfully');
    // console.log('🧪 BACKEND: Test ID:', detail.test_id?._id);
    // console.log('📦 BACKEND: Order ID:', detail.order_id?._id);

    // Check if the test is assigned to this staff (skip if no auth)
    if (req.user && (!detail.staff_id || detail.staff_id.toString() !== staff_id.toString())) {
      // console.log('❌ BACKEND: Authorization failed - test not assigned to staff');
      return res.status(403).json({ message: "You are not authorized to run tests for this test" });
    }

    // Check if sample is collected
    if (!detail.sample_collected) {
      // console.log('❌ BACKEND: Sample not collected for test');
      return res.status(400).json({ message: "⚠️ Sample must be collected before running the test" });
    }

    // Check if result already exists
    const existingResult = await Result.findOne({ detail_id });
    if (existingResult) {
      console.log('❌ BACKEND: Result already exists for this test');
      return res.status(400).json({ message: "⚠️ Result already exists for this test" });
    }

    const test = detail.test_id;

    if (!test || !test._id) {
      console.log('❌ BACKEND: Test information not found');
      return res.status(400).json({ message: "⚠️ Test information not found for this order detail" });
    }
    
    const order = detail.order_id;
    
    if (!order || !order._id) {
      console.log('❌ BACKEND: Order not found');
      return res.status(400).json({ message: "⚠️ Order not found for this test detail" });
    }
    
    const patient = order.patient_id;
    
    if (!patient || !patient._id) {
      console.log('❌ BACKEND: Patient information not found');
      return res.status(400).json({ message: "⚠️ Patient information not found for this order" });
    }
    
    console.log('✅ BACKEND SIMULATION STEP 2: All data loaded successfully');
    console.log('👤 BACKEND: Patient:', patient.full_name?.first, patient.full_name?.last);
    console.log('🧪 BACKEND: Test:', test.test_name, '(' + test.test_code + ')');
    console.log('📋 BACKEND: Order:', order._id);

    // Update status to in_progress
    detail.status = 'in_progress';
    await detail.save();
    console.log('📝 BACKEND: Order detail status updated to in_progress');

    console.log('🎲 BACKEND SIMULATION STEP 3: Generating random results');

    // 2️⃣ Generate random results (instead of HL7)
    let randomResult = {};
    let isAbnormal = false;

    // Get test components if they exist
    const testComponents = await TestComponent.find({ test_id: test._id, is_active: true }).sort({ display_order: 1 });

    console.log('🧬 BACKEND: Test components found:', testComponents.length);

    if (testComponents.length > 0) {
      console.log('🔬 BACKEND: Processing multi-component test');
      // Multi-component test
      const components = [];
      for (const component of testComponents) {
        console.log('🧫 BACKEND: Generating result for component:', component.component_name);
        const componentResult = generateRandomResult(component);
        console.log('🧫 BACKEND: Generated value:', componentResult.value, 'Abnormal:', componentResult.isAbnormal);

        components.push({
          component_id: component._id,
          component_name: component.component_name,
          component_value: componentResult.value,
          units: component.units,
          reference_range: component.reference_range,
          is_abnormal: componentResult.isAbnormal,
          remarks: '', // Can be left empty or generated
        });
        if (componentResult.isAbnormal) isAbnormal = true;
      }
      randomResult = {
        has_components: true,
        components: components,
        is_abnormal: isAbnormal,
        abnormal_components_count: components.filter(c => c.is_abnormal).length,
        remarks: 'Generated via HL7 simulation',
      };
      console.log('✅ BACKEND: Multi-component result generated with', components.length, 'components');
    } else {
      console.log('🔬 BACKEND: Processing single-value test');
      // Single-value test
      const resultValue = generateRandomResult({
        reference_range: test.reference_range,
        component_name: test.test_name,
        component_code: test.test_code,
        units: test.units
      }).value;

      console.log('🧫 BACKEND: Generated single value:', resultValue);

      // Check if abnormal for single value
      let singleIsAbnormal = false;
      if (test.reference_range && test.reference_range.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)/)) {
        const rangeMatch = test.reference_range.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)/);
        const min = parseFloat(rangeMatch[1]);
        const max = parseFloat(rangeMatch[2]);
        const value = parseFloat(resultValue);
        if (value < min || value > max) {
          singleIsAbnormal = true;
        }
        console.log('📏 BACKEND: Reference range:', min, '-', max, 'Value abnormal:', singleIsAbnormal);
      }
      randomResult = {
        has_components: false,
        result_value: resultValue,
        units: test.units,
        reference_range: test.reference_range,
        is_abnormal: singleIsAbnormal,
        remarks: 'Generated via HL7 simulation',
      };
      isAbnormal = singleIsAbnormal;
      console.log('✅ BACKEND: Single-value result generated');
    }

    console.log('🎯 BACKEND SIMULATION STEP 4: Preparing response');
    const responseData = {
      message: "🏥 Test simulation completed successfully. Review and save the results.",
      detail_id: detail._id,
      test_name: test.test_name,
      status: 'in_progress',
      simulated_result: true,
      is_abnormal: isAbnormal,
      random_result: randomResult, // New: Return generated results for frontend display
    };

    console.log('📤 BACKEND: Response data keys:', Object.keys(responseData));
    console.log('📤 BACKEND: random_result present:', responseData.random_result != null);
    console.log('📤 BACKEND: has_components:', responseData.random_result?.has_components);
    console.log('📤 BACKEND: is_abnormal:', responseData.random_result?.is_abnormal);

    console.log('🎉 BACKEND SIMULATION SUCCESS: HL7 simulation completed successfully!');
    res.json({
      success: true,
      ...responseData
    });

  } catch (error) {
    console.error("💥 BACKEND SIMULATION ERROR:", error);
    console.error("📊 BACKEND: Error stack:", error.stack);
    res.status(500).json({ message: error.message });
  }
};

// Helper function to generate random test results
function generateRandomResult(component) {
  console.log('🎲 BACKEND GENERATE: Starting random result generation for:', component.component_name || component.test_name);

  let value = '';
  let isAbnormal = false;

  // Parse reference range if available
  if (component.reference_range) {
    console.log('📏 BACKEND GENERATE: Reference range found:', component.reference_range);
    const rangeMatch = component.reference_range.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)/);
    if (rangeMatch) {
      const min = parseFloat(rangeMatch[1]);
      const max = parseFloat(rangeMatch[2]);
      console.log('📏 BACKEND GENERATE: Parsed range - Min:', min, 'Max:', max);

      // 80% chance of normal result, 20% chance of abnormal
      if (Math.random() < 0.8) {
        // Normal range
        value = (Math.random() * (max - min) + min).toFixed(2);
        console.log('✅ BACKEND GENERATE: Generated normal value:', value);
      } else {
        // Abnormal - either high or low
        if (Math.random() < 0.5) {
          // High
          value = (max + Math.random() * max * 0.5).toFixed(2);
          console.log('⚠️ BACKEND GENERATE: Generated high abnormal value:', value);
        } else {
          // Low
          value = (min - Math.random() * min * 0.5).toFixed(2);
          console.log('⚠️ BACKEND GENERATE: Generated low abnormal value:', value);
        }
        isAbnormal = true;
      }
    } else {
      // Check if reference range contains qualitative values (like "Yellow", "Clear", "Negative")
      const qualitativeValues = component.reference_range.trim();
      console.log('🎨 BACKEND GENERATE: Qualitative reference range detected:', qualitativeValues);

      // For urine analysis qualitative components
      if (qualitativeValues === 'Yellow' || qualitativeValues === 'Clear' || qualitativeValues === 'Negative') {
        // 90% chance of normal qualitative result
        if (Math.random() < 0.9) {
          value = qualitativeValues;
          console.log('✅ BACKEND GENERATE: Generated normal qualitative value:', value);
        } else {
          // Generate abnormal qualitative values
          if (qualitativeValues === 'Yellow') {
            value = Math.random() < 0.5 ? 'Pale Yellow' : 'Dark Yellow';
          } else if (qualitativeValues === 'Clear') {
            value = Math.random() < 0.5 ? 'Cloudy' : 'Turbid';
          } else if (qualitativeValues === 'Negative') {
            value = Math.random() < 0.5 ? 'Trace' : 'Positive';
          }
          isAbnormal = true;
          console.log('⚠️ BACKEND GENERATE: Generated abnormal qualitative value:', value);
        }
      } else {
        // No valid numeric range and not recognized qualitative, generate random numeric value
        value = (Math.random() * 100 + 1).toFixed(2);
        console.log('🔄 BACKEND GENERATE: Generated fallback numeric value:', value);
      }
    }
  } else {
    // No reference range, generate random value based on test type
    const testName = component.component_name?.toLowerCase() || '';
    console.log('📊 BACKEND GENERATE: No reference range, using test type logic for:', testName);

    if (testName.includes('count') || testName.includes('percentage')) {
      value = (Math.random() * 100).toFixed(1);
    } else if (testName.includes('ratio') || testName.includes('index')) {
      value = (Math.random() * 10).toFixed(2);
    } else {
      value = (Math.random() * 200 + 1).toFixed(2);
    }
    console.log('🔄 BACKEND GENERATE: Generated type-based value:', value);
  }

  console.log('🎯 BACKEND GENERATE: Result generation complete - Value:', value, 'Abnormal:', isAbnormal);
  return { value, isAbnormal };
}




exports.reportInventoryIssue = async (req, res) => {
  try {
    const staff_id = req.user._id;
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
    const staff_id = req.user._id;
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
    const staff_id = req.user._id;
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
    const staff_id = req.user._id; // Use authenticated staff ID
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
      // If sample is collected but status is not updated, fix the status
      if (!['collected', 'in_progress', 'completed'].includes(detail.status)) {
        detail.status = 'collected';
        detail.sample_collected_date = detail.sample_collected_date || new Date();
        await detail.save();
        
        // Log the fix
        const loggingStaff = await Staff.findById(staff_id).select('username');
        await logAction(
          staff_id, 
          loggingStaff.username,
          `Fixed inconsistent status for collected sample: ${detail.test_id.test_name}`,
          'OrderDetails',
          detail_id
        );
      }
      
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

    // Mark sample as collected (barcode functionality removed)
    detail.sample_collected = true;
    detail.sample_collected_date = new Date();
    detail.status = 'collected';

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

    const validStatuses = ["pending", "collected", "in_progress", "completed"];
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

// ✅ Assign Test to Me (Self-Assignment)
exports.assignTestToMe = async (req, res) => {
  try {
    const { detail_id } = req.body;
    const staff_id = req.user._id;

    // Find the order detail
    const detail = await OrderDetails.findById(detail_id)
      .populate('test_id', 'test_name sample_type tube_type')
      .populate('order_id', 'order_id patient_name');

    if (!detail) {
      return res.status(404).json({ message: "❌ Order detail not found" });
    }

    // Check if test is already assigned to someone
    if (detail.staff_id && detail.staff_id.toString() !== staff_id) {
      return res.status(400).json({ 
        message: "⚠️ This test is already assigned to another staff member" 
      });
    }

    // Check if test is already assigned to this staff
    if (detail.staff_id && detail.staff_id.toString() === staff_id) {
      return res.status(400).json({ 
        message: "ℹ️ You are already assigned to this test" 
      });
    }

    // Assign the test to this staff
    detail.staff_id = staff_id;
    detail.assigned_at = new Date();
    detail.status = 'assigned';

    await detail.save();

    // Get staff info for logging
    const staff = await Staff.findById(staff_id).select('username full_name');

    // Log the action
    await logAction(
      staff_id, 
      staff.username,
      `Self-assigned to test: ${detail.test_id.test_name} for order ${detail.order_id.order_id}`,
      'OrderDetails',
      detail_id
    );

    // Create notification for the staff
    await Notification.create({
      sender_id: staff_id,
      receiver_id: staff_id,
      title: 'Test Self-Assigned',
      message: `You have assigned yourself to ${detail.test_id.test_name} for patient ${detail.order_id.patient_name}`,
      type: 'assignment',
      priority: 'normal'
    });

    res.json({ 
      success: true,
      message: `✅ Successfully assigned ${detail.test_id.test_name} to yourself`,
      detail: {
        _id: detail._id,
        test_name: detail.test_id.test_name,
        sample_type: detail.test_id.sample_type,
        tube_type: detail.test_id.tube_type,
        status: detail.status,
        assigned_at: detail.assigned_at,
        staff_assigned: {
          staff_id: staff._id,
          name: `${staff.full_name.first} ${staff.full_name.last}`,
          username: staff.username
        }
      }
    });

  } catch (err) {
    console.error("Error assigning test to staff:", err);
    res.status(500).json({ error: err.message });
  }
};



// ✅ Get Staff Assigned Devices
exports.getStaffDevices = async (req, res) => {
  try {
    const { staff_id } = req.params;

    // Verify requesting staff can access this
    if (req.user._id !== staff_id && req.user.role !== 'Owner') {
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


// ✅ Fix assigned test statuses (for tests that have staff_id but wrong status)
exports.fixAssignedTestStatuses = async (req, res) => {
  try {
    const staff_id = req.user._id;

    // Get staff to find their lab
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Find all order details for this lab that have staff_id but status is not 'assigned', 'collected', 'in_progress', or 'completed'
    const detailsToFix = await OrderDetails.find({
      staff_id: { $ne: null },
      status: { $nin: ['assigned', 'collected', 'in_progress', 'completed'] }
    }).populate('order_id', 'owner_id');

    // Filter to only tests from this lab
    const labDetailsToFix = detailsToFix.filter(detail => 
      detail.order_id && detail.order_id.owner_id.toString() === staff.owner_id.toString()
    );

    console.log(`Found ${labDetailsToFix.length} tests in lab that need status fix`);

    let fixedCount = 0;
    for (const detail of labDetailsToFix) {
      // Set status to 'assigned' if not already in a later status
      if (detail.status !== 'completed' && detail.status !== 'collected' && detail.status !== 'in_progress') {
        detail.status = 'assigned';
        detail.assigned_at = detail.assigned_at || new Date();
        await detail.save();
        fixedCount++;
      }
    }

    res.json({
      success: true,
      message: `Fixed ${fixedCount} test statuses`,
      total_found: labDetailsToFix.length,
      fixed: fixedCount
    });

  } catch (err) {
    console.error("Error fixing assigned test statuses:", err);
    res.status(500).json({ error: err.message });
  }
};

// ✅ Staff Dashboard (with devices & inventory)
exports.getStaffDashboard = async (req, res) => {
  try {
    const staff_id = req.user._id; // from authMiddleware

    // 1️⃣ Assigned tests (all statuses)
    const assignedTests = await OrderDetails.find({ staff_id })
      .populate('test_id', 'test_name test_code sample_type')
      .populate({
        path: 'order_id',
        select: 'order_date status remarks',
        populate: { 
          path: 'patient_id', 
          select: 'full_name patient_id email phone_number' 
        }
      })
      .sort({ 
        createdAt: -1    // Newest first
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
    const staff_id = req.user._id;

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
      .populate('doctor_id', 'name')
      .sort({ order_date: -1 });

    // Get order details for each order
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const details = await OrderDetails.find({ order_id: order._id })
          .populate('test_id', 'test_name test_code price category')
          .populate('staff_id', 'full_name employee_number username');
        
        const totalCost = details.reduce((sum, detail) => {
          return sum + (detail.test_id?.price || 0);
        }, 0);

        // Count completed and pending tests
        const completedTests = details.filter(d => d.status === 'completed').length;
        const pendingTests = details.filter(d => d.status === 'pending').length;

        // Get doctor name if available
        const doctorName = order.doctor_id?.name
          ? `Dr. ${order.doctor_id.name.first} ${order.doctor_id.name.middle || ''} ${order.doctor_id.name.last}`.trim()
          : null;

        return {
          order_id: order._id,
          patient_info: order.is_patient_registered
            ? {
                full_name: order.patient_id?.full_name,
                identity_number: order.patient_id?.identity_number,
                phone_number: order.patient_id?.phone_number || 'Not provided',
                email: order.patient_id?.email || 'Not provided',
              }
            : order.temp_patient_info || {
                full_name: { first: 'Walk-in', last: 'Patient' },
                identity_number: 'N/A',
                phone_number: 'Not provided',
                email: 'Not provided'
              },
          patient_id: order.patient_id?._id,
          is_patient_registered: order.is_patient_registered,
          order_date: order.order_date,
          status: order.status,
          doctor_name: doctorName,
          remarks: order.remarks,
          tests: details.map(d => ({
            detail_id: d._id,
            test_id: d.test_id?._id,
            test_name: d.test_id?.test_name,
            test_code: d.test_id?.test_code,
            price: d.test_id?.price,
            category: d.test_id?.category,
            status: d.status,
            staff_id: d.staff_id,
            assigned_to: d.staff_id ? {
              _id: d.staff_id._id,
              name: `${d.staff_id.full_name.first} ${d.staff_id.full_name.last}`,
              employee_number: d.staff_id.employee_number,
              username: d.staff_id.username
            } : null
          })),
          total_cost: totalCost,
          test_count: details.length,
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
 * @desc    Create walk-in order (when patient comes to lab)
 * @route   POST /api/staff/create-walk-in-order
 * @access  Private (Staff)
 */
exports.createWalkInOrder = async (req, res) => {
  try {
    const staff_id = req.user._id;
    const { patient_info, test_ids, doctor_id } = req.body;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Validate test_ids
    if (!test_ids || test_ids.length === 0) {
      return res.status(400).json({ message: "At least one test must be selected" });
    }

    // Check if patient already exists (by full name and mobile number)
    let patient = await Patient.findOne({
      $and: [
        { phone_number: patient_info.phone_number },
        { 'full_name.first': patient_info.full_name.first },
        { 'full_name.last': patient_info.full_name.last }
      ]
    });

    let isNewPatient = false;
    let tempPassword = null;
    let username = null;

    // If patient doesn't exist, create new patient account
    if (!patient) {
      isNewPatient = true;
      
      // Generate username from email (part before @)
      username = patient_info.email.split('@')[0];
      
      // Check if username exists, append number if needed
      let usernameExists = await Patient.findOne({ username });
      let counter = 1;
      while (usernameExists) {
        username = `${patient_info.email.split('@')[0]}${counter}`;
        usernameExists = await Patient.findOne({ username });
        counter++;
      }

      // Generate random 8-character password
      tempPassword = Math.random().toString(36).slice(-8) + Math.random().toString(36).slice(-8).toUpperCase();

      // Generate unique patient ID
      let newPatientId = '1000';

      try {
        // Find the highest numeric patient_id
        const lastPatient = await Patient.findOne({
          patient_id: { $exists: true, $ne: null, $ne: 'NaN', $regex: /^\d+$/ }
        }).sort({ patient_id: -1 });

        if (lastPatient && lastPatient.patient_id) {
          const lastId = parseInt(lastPatient.patient_id);
          if (!isNaN(lastId)) {
            newPatientId = (lastId + 1).toString();
          }
        }
      } catch (error) {
        console.warn('Error generating patient ID, using timestamp fallback:', error.message);
        // If there's any issue, generate a timestamp-based ID to ensure uniqueness
        newPatientId = Date.now().toString();
      }

      // Ensure patient_id is always a valid string
      if (!newPatientId || newPatientId === 'NaN') {
        newPatientId = Date.now().toString();
      }

      console.log(`Generated new patient ID: ${newPatientId}`);

      // Create patient account (password will be hashed by model's pre-save hook)
      patient = await Patient.create({
        patient_id: newPatientId,
        username,
        password: tempPassword, // Plain password - will be hashed by model
        full_name: patient_info.full_name,
        identity_number: patient_info.identity_number,
        birthday: patient_info.birthday,
        gender: patient_info.gender,
        social_status: patient_info.social_status,
        phone_number: patient_info.phone_number,
        email: patient_info.email,
        address: patient_info.address,
        insurance_provider: patient_info.insurance_provider,
        insurance_number: patient_info.insurance_number,
        notes: patient_info.notes,
        is_active: true,
        created_by_staff: staff_id
      });
    }

    // Create order linked to patient
    const order = await Order.create({
      owner_id: staff.owner_id,
      patient_id: patient._id,
      doctor_id: doctor_id || null,
      order_date: new Date(),
      status: 'processing',
      is_patient_registered: true,
      requested_by: staff_id
    });

    // Create order details for each test
    const orderDetails = await Promise.all(
      test_ids.map(async (test_id) => {
        return await OrderDetails.create({
          order_id: order._id,
          test_id,
          status: 'pending',
          staff_id: staff_id
        });
      })
    );

    // Get test details for response
    const details = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price');

    // Create invoice automatically
    const subtotal = details.reduce((sum, detail) => {
      return sum + (detail.test_id.price || 0);
    }, 0);

    // Generate invoice ID
    const invoiceCount = await Invoice.countDocuments();
    const invoiceId = `INV-${String(invoiceCount + 1).padStart(6, '0')}`;

    const invoice = await Invoice.create({
      invoice_id: invoiceId,
      order_id: order._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'paid', // Mark as paid initially
      payment_method: 'cash', // Default payment method
      payment_date: new Date(),
      paid_by: staff_id,
      owner_id: order.owner_id,
      items: details.map(d => ({
        test_id: d.test_id._id,
        test_name: d.test_id.test_name,
        price: d.test_id.price,
        quantity: 1
      }))
    });

    // Send invoice notification to patient
    await Notification.create({
      sender_id: staff_id,
      sender_model: 'Staff',
      receiver_id: patient._id,
      receiver_model: 'Patient',
      type: 'payment',
      title: 'Invoice Generated',
      message: `Your invoice has been generated. Total: ${subtotal} ILS. Payment status: Paid.`
    });

    // Send account activation notification (both WhatsApp and Email) if new patient
    if (isNewPatient && tempPassword && username) {
      try {
        const notificationSuccess = await sendAccountActivation(
          patient_info,
          username,
          tempPassword,
          patient.patient_id,
          null, 
          details.length,
          order.order_date
        );

        if (notificationSuccess) {
          console.log(`Account activation notification sent to new patient ${patient_info.full_name.first} ${patient_info.full_name.last} via WhatsApp and Email`);
        }
      } catch (notificationError) {
        console.error('Failed to send account activation notification:', notificationError);
        // Continue with the response - don't fail the order creation
      }
    }

    // Send invoice PDF to patient (both new and existing patients)
    try {
      const lab = await LabOwner.findById(staff.owner_id);
      const invoiceUrl = `${process.env.FRONTEND_URL || 'http://localhost:8080'}/patient-dashboard/bill-details/${order._id}`;
      
      const invoicePdfSuccess = await sendInvoiceReport(
        patient,
        invoice,
        invoiceUrl,
        lab.lab_name
      );

      if (invoicePdfSuccess) {
        console.log(`Invoice PDF sent to patient ${patient_info.full_name.first} ${patient_info.full_name.last} via WhatsApp and Email`);
      }
    } catch (invoiceError) {
      console.error('Failed to send invoice PDF:', invoiceError);
      // Continue with the response - don't fail the order creation
    }

    res.status(201).json({
      success: true,
      message: isNewPatient 
        ? "Walk-in order created and patient account created successfully. Credentials and invoice PDF sent via WhatsApp and email."
        : "Walk-in order created successfully for existing patient. Invoice PDF sent via WhatsApp and email.",
      order: {
        _id: order._id,
        order_date: order.order_date,
        status: order.status,
        patient_id: patient._id
      },
      patient: {
        _id: patient._id,
        patient_id: patient.patient_id,
        full_name: patient.full_name,
        email: patient.email,
        is_new_account: isNewPatient
      },
      credentials: isNewPatient ? {
        username,
        password: tempPassword,
        message: "Credentials have been sent to patient's WhatsApp and email"
      } : null,
      tests: details.map(d => ({
        test_name: d.test_id.test_name,
        test_code: d.test_id.test_code,
        price: d.test_id.price,
        status: d.status
      })),
      total_tests: details.length
    });

  } catch (err) {
    console.error("Error creating walk-in order:", err);
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
    const staff_id = req.user._id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Get all pending orders for this lab where patient not yet registered
    const pendingOrders = await Order.find({
      owner_id: staff.owner_id,
      status: 'pending',
      is_patient_registered: false
    })
    .sort({ 
      order_date: 1     // By date (oldest first)
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
          patient_info: order.temp_patient_info,
          order_date: order.order_date,
          remarks: order.remarks,
          tests: details.map(d => ({
            test_name: d.test_id.test_name,
            test_code: d.test_id.test_code,
            price: d.test_id.price,
            status: d.status
          })),
          total_cost: totalCost,
          test_count: details.length
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
    const staff_id = req.user._id;

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
        `Your order (${order._id}) is being processed.\n` +
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
          message: `You have been assigned to perform ${test.test_name} for patient ${patient.full_name.first} ${patient.full_name.last} (Order: ${order._id})`
        });
      }
      // If manual test, leave staff_id null for manual assignment by owner
    }

    // Create invoice
    const subtotal = orderDetails.reduce((sum, detail) => {
      return sum + (detail.test_id.price || 0);
    }, 0);

    // Generate invoice ID
    const invoiceCount = await Invoice.countDocuments();
    const invoiceId = `INV-${String(invoiceCount + 1).padStart(6, '0')}`;

    const invoice = await Invoice.create({
      invoice_id: invoiceId,
      order_id: order._id,
      invoice_date: new Date(),
      subtotal,
      discount: 0,
      total_amount: subtotal,
      payment_status: 'paid', // Mark as paid initially
      payment_method: 'cash', // Default payment method
      payment_date: new Date(),
      paid_by: staff_id,
      owner_id: order.owner_id,
      items: details.map(d => ({
        test_id: d.test_id._id,
        test_name: d.test_id.test_name,
        price: d.test_id.price,
        quantity: 1
      }))
    });

    // Send notification to patient
    await Notification.create({
      sender_id: staff_id,
      sender_model: 'Staff',
      receiver_id: patient._id,
      receiver_model: 'Patient',
      type: 'payment',
      title: 'Invoice Generated',
      message: `Your invoice has been generated. Total: ${subtotal} ILS. Payment status: Paid.`
    });

    // Log action
    const loggingStaff = await Staff.findById(staff_id).select('username');
    await logAction(
      staff_id,
      loggingStaff.username,
      isNewPatient 
        ? `Registered new patient ${patient.patient_id} from order ${order._id}`
        : `Linked existing patient ${patient.patient_id} to order ${order._id}`,
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
      createdAt: -1    // By newest first
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
        order_status: test.order_id?.status
      }))
    });

  } catch (err) {
    console.error("Error fetching unassigned tests:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get unassigned tests for staff (order details without staff assignment)
 * @route   GET /api/staff/my-unassigned-tests
 * @access  Private (Staff)
 */
exports.getMyUnassignedTests = async (req, res) => {
  try {
    const staff_id = req.user._id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Find all order details where staff_id is null and order belongs to this lab
    const unassignedTests = await OrderDetails.find({
      staff_id: null
    })
    .populate({
      path: 'order_id',
      match: { owner_id: staff.owner_id },
      populate: { path: 'patient_id', select: 'full_name patient_id' }
    })
    .populate('test_id', 'test_name test_code method sample_type tube_type price')
    .sort({
      createdAt: -1    // By newest first
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
        tube_type: test.test_id?.tube_type,
        price: test.test_id?.price,
        status: test.status,
        patient_name: test.order_id?.patient_id
          ? `${test.order_id.patient_id.full_name.first} ${test.order_id.patient_id.full_name.last}`
          : 'Unknown Patient',
        patient_id: test.order_id?.patient_id?.patient_id,
        order_id: test.order_id?.order_id,
        order_date: test.order_id?.order_date,
        order_status: test.order_id?.status
      }))
    });

  } catch (err) {
    console.error("Error fetching unassigned tests for staff:", err);
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
    detail.assigned_at = new Date();
    detail.status = 'assigned';
    await detail.save();

    // Send notification to newly assigned staff
    await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: staff_id,
      receiver_model: 'Staff',
      type: 'system',
      title: previousStaffId ? 'Test Reassigned to You' : 'New Test Assignment',
      message: `You have been assigned to perform ${detail.test_id.test_name} for patient ${detail.order_id.patient_id?.full_name.first || 'Unknown'} (Order: ${detail.order_id._id})`
    });

    // If reassignment, notify previous staff
    if (previousStaffId && previousStaffId.toString() !== staff_id.toString()) {
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: previousStaffId,
        receiver_model: 'Staff',
        type: 'system',
        title: 'Test Reassigned',
        message: `Test ${detail.test_id.test_name} (Order: ${detail.order_id._id}) has been reassigned to another staff member`
      });
    }

    // Log action
    const LabOwner = require('../models/Owner');
    const loggingOwner = await LabOwner.findById(req.user._id).select('username');
    await logAction(
      req.user._id,
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
    const { orderId } = req.params;

    const orderDetails = await OrderDetails.find({ order_id: orderId })
      .populate('test_id', 'test_name test_code sample_type price device_id')
      .populate('order_id', 'status')
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

    // 🔍 Check if all tests in this order are completed and update order status
    try {
      const order = await Order.findById(detail.order_id);
      if (order) {
        const allOrderDetails = await OrderDetails.find({ order_id: order._id });
        const totalTests = allOrderDetails.length;
        const completedTests = allOrderDetails.filter(d => d.status === 'completed').length;
        
        // If all tests are completed, mark the order as completed
        if (totalTests > 0 && completedTests === totalTests && order.status !== 'completed') {
          order.status = 'completed';
          await order.save();
          console.log(`Order ${order._id} marked as completed - all ${totalTests} tests are done`);
        }
      }
    } catch (orderCheckError) {
      console.error('Error checking order completion:', orderCheckError);
      // Don't fail the response for this
    }

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

    // Barcode functionality has been removed
    res.json({
      success: true,
      message: "Barcode functionality is no longer available",
      detail_id: detail_id
    });

  } catch (err) {
    console.error("Error in generateSampleBarcode:", err);
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
    const { orderId } = req.params;

    // Barcode functionality has been removed
    res.json({
      success: true,
      message: "Barcode functionality is no longer available",
      order_id: orderId
    });

  } catch (err) {
    console.error("Error in generateBarcode:", err);
    res.status(500).json({ error: err.message });
  }
};
exports.getMyAssignedTests = async (req, res) => {
  try {
    const staff_id = req.user._id;
    const { status_filter, device_id } = req.query;

    console.log('🔍 BACKEND getMyAssignedTests: Called for staff:', staff_id.toString());
    console.log('🔍 BACKEND getMyAssignedTests: status_filter:', status_filter, 'device_id:', device_id);

    // Build query
    let query = { staff_id };
    if (status_filter) {
      if (status_filter === 'assigned') {
        // Include both 'assigned' and 'pending' statuses for assigned filter
        query.status = { $in: ['assigned', 'pending'] };
      } else {
        query.status = status_filter;
      }
    }

    console.log('🔍 BACKEND getMyAssignedTests: Final query:', JSON.stringify(query, null, 2));

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

    console.log('🔍 BACKEND getMyAssignedTests: Raw query results count:', assignedTests.length);
    if (assignedTests.length > 0) {
      console.log('🔍 BACKEND getMyAssignedTests: First test sample:', JSON.stringify(assignedTests[0], null, 2));
    }

    // Get results for completed tests
    const completedDetailIds = assignedTests
      .filter(d => d.status === 'completed')
      .map(d => d._id);
    
    const Result = require('../models/Result');
    const ResultComponent = require('../models/ResultComponent');
    
    const results = await Result.find({ detail_id: { $in: completedDetailIds } });
    const resultIds = results.map(r => r._id);
    const components = await ResultComponent.find({ result_id: { $in: resultIds } })
      .populate('component_id')
      .sort({ 'component_id.display_order': 1 });

    // Group tests by status
    const statusGroups = {
      assigned: [],
      collected: [],
      in_progress: [],
      completed: []
    };

    // Get unique devices
    const devices = new Set();

    assignedTests.forEach(detail => {
      // Get result data for completed tests
      let resultData = null;
      if (detail.status === 'completed') {
        const result = results.find(r => r.detail_id.toString() === detail._id.toString());
        if (result) {
          const testComponents = result.has_components ? 
            components
              .filter(c => c.result_id.toString() === result._id.toString())
              .map(c => ({
                component_name: c.component_name,
                component_value: c.component_value,
                units: c.units,
                reference_range: c.reference_range,
                is_abnormal: c.is_abnormal,
                remarks: c.remarks
              })) : [];
          
          resultData = {
            result_value: result.result_value,
            units: result.units,
            reference_range: result.reference_range,
            remarks: result.remarks,
            has_components: result.has_components,
            is_abnormal: result.is_abnormal,
            components: testComponents
          };
        }
      }
      
      const testData = {
        detail_id: detail._id,
        test_id: detail.test_id?._id,
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
        order_date: detail.order_id?.order_date,
        status: detail.status,
        sample_collected: detail.sample_collected,
        sample_collected_date: detail.sample_collected_date,
        assigned_at: detail.assigned_at,
        result_uploaded: detail.result_id ? true : false,
        result: resultData
      };

      // Add to device set
      if (testData.device?.device_id) {
        devices.add(JSON.stringify(testData.device));
      }

      // Group by status
      // Treat 'pending' as 'assigned' for display purposes
      const displayStatus = detail.status === 'pending' ? 'assigned' : detail.status;
      statusGroups[displayStatus]?.push(testData);
    });

    // Calculate statistics
    const stats = {
      total: assignedTests.length,
      assigned: statusGroups.assigned.length,
      collected: statusGroups.collected.length,
      in_progress: statusGroups.in_progress.length,
      completed: statusGroups.completed.length,
      pending_work: statusGroups.assigned.length + statusGroups.collected.length + statusGroups.in_progress.length
    };

    console.log('🔍 BACKEND getMyAssignedTests: Status groups counts:', {
      assigned: statusGroups.assigned.length,
      collected: statusGroups.collected.length,
      in_progress: statusGroups.in_progress.length,
      completed: statusGroups.completed.length
    });

    res.json({
      success: true,
      stats,
      devices: Array.from(devices).map(d => JSON.parse(d)),
      tests_by_status: statusGroups,
      all_tests: assignedTests.map(detail => ({
        detail_id: detail._id,
        test_id: detail.test_id?._id,
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
        status: detail.status,
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
    const staff_id = req.user._id;

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
    const staff_id = req.user._id;
    const { target_type, target_id, rating, message, is_anonymous } = req.body;

    // Validate required fields
    if (!target_type || !rating) {
      return res.status(400).json({ message: '⚠️ Target type and rating are required' });
    }

    // Validate target_type
    const validTargetTypes = ['lab', 'test', 'order', 'system', 'service'];
    if (!validTargetTypes.includes(target_type)) {
      return res.status(400).json({ message: '⚠️ Invalid target type. Must be lab, test, order, system, or service' });
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

    // Check for 28-day cooldown (users can submit feedback every 4 weeks)
    const twentyEightDaysAgo = new Date(Date.now() - 28 * 24 * 60 * 60 * 1000);
    const lastFeedback = await Feedback.findOne({
      user_id: staff_id,
      createdAt: { $gte: twentyEightDaysAgo }
    }).sort({ createdAt: -1 });

    if (lastFeedback) {
      const daysUntilNext = Math.ceil((lastFeedback.createdAt.getTime() + 28 * 24 * 60 * 60 * 1000 - Date.now()) / (24 * 60 * 60 * 1000));
      return res.status(429).json({
        message: `⏳ You can submit feedback again in ${daysUntilNext} days. Feedback is limited to once every 4 weeks.`
      });
    }

    // Determine target model for refPath
    let target_model = null;
    if (!['system', 'service'].includes(target_type)) {
      switch (target_type) {
        case 'lab':
          target_model = 'Owner';
          break;
        case 'test':
          target_model = 'Test';
          break;
        case 'order':
          target_model = 'Order';
          break;
      }
    }

    // Create feedback
    const feedback = new Feedback({
      user_id: staff_id,
      user_model: 'Staff',
      target_type,
      target_id: target_type === 'system' ? null : target_id,
      target_model,
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
    const staff_id = req.user._id;
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
        select: 'name lab_name test_name barcode'
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
    const staff_id = req.user._id;
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
    if (req.user._id !== staff_id && req.user.role !== 'Owner') {
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
    const staff_id = req.user._id;
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

/**
 * @desc    Get test components for staff (when uploading results)
 * @route   GET /api/staff/tests/:testId/components
 * @access  Private (Staff)
 */
exports.getTestComponentsForStaff = async (req, res) => {
  try {
    const { testId } = req.params;

    // Verify test exists
    const test = await Test.findById(testId);
    if (!test) {
      return res.status(404).json({ message: "Test not found" });
    }

    // Get active components sorted by display order
    const components = await TestComponent.find({ 
      test_id: testId, 
      is_active: true 
    }).sort({ display_order: 1, createdAt: 1 });

    res.json({
      test: {
        _id: test._id,
        test_name: test.test_name,
        test_code: test.test_code
      },
      has_components: components.length > 0,
      components: components.map(c => ({
        _id: c._id,
        component_name: c.component_name,
        component_code: c.component_code,
        units: c.units,
        reference_range: c.reference_range,
        min_value: c.min_value,
        max_value: c.max_value,
        description: c.description,
        display_order: c.display_order
      }))
    });
  } catch (err) {
    console.error("Error getting test components:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get All Results for Staff's Lab
 * @route   GET /api/staff/results
 * @access  Private (Staff)
 */
exports.getAllResults = async (req, res) => {
  try {
    const staff_id = req.user._id;
    const { page = 1, limit = 50, startDate, endDate, status, patientName, testName } = req.query;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Build query for results through order details
    let query = { owner_id: staff.owner_id };

    // Filter by date range if provided
    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get orders with their details and results
    const orders = await Order.find(query)
      .populate('patient_id', 'full_name patient_id phone_number email')
      .populate('doctor_id', 'name')
      .sort({ order_date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Filter out orders where patient_id doesn't exist
    const validOrders = orders.filter(order => order.patient_id);

    if (validOrders.length === 0) {
      return res.json({
        total: 0,
        page: parseInt(page),
        totalPages: 0,
        results: []
      });
    }

    // Get all order details for these orders
    const orderIds = validOrders.map(o => o._id);
    const orderDetails = await OrderDetails.find({ order_id: { $in: orderIds } })
      .populate('test_id', 'test_name test_code price')
      .populate('staff_id', 'full_name employee_number')
      .select('order_id test_id staff_id status result_id');

    // Get all results for these order details
    const detailIds = orderDetails.map(d => d._id);
    const results = await Result.find({ detail_id: { $in: detailIds } })
      .sort({ createdAt: -1 });

    // Group results by order
    const resultsByOrder = {};

    for (const order of validOrders) {
      const orderObj = order.toObject();
      const orderDetailIds = orderDetails
        .filter(d => d.order_id.toString() === order._id.toString())
        .map(d => d._id);

      const orderResults = results.filter(r => orderDetailIds.includes(r.detail_id));

      if (orderResults.length > 0) {
        // Apply filters
        let filteredResults = orderResults;

        if (status) {
          filteredResults = filteredResults.filter(r => r.status === status);
        }

        if (patientName) {
          const patientFullName = `${order.patient_id.full_name.first} ${order.patient_id.full_name.last}`.toLowerCase();
          if (!patientFullName.includes(patientName.toLowerCase())) {
            continue;
          }
        }

        if (testName) {
          filteredResults = filteredResults.filter(r => {
            const detail = orderDetails.find(d => d._id.toString() === r.detail_id.toString());
            return detail && detail.test_id && detail.test_id.test_name.toLowerCase().includes(testName.toLowerCase());
          });
        }

        if (filteredResults.length > 0) {
          resultsByOrder[order._id] = {
            order: {
              _id: order._id,
              order_id: order.order_id,
              order_date: order.order_date,
              status: order.status,
              patient_name: `${order.patient_id.full_name.first} ${order.patient_id.full_name.last}`,
              patient_id: order.patient_id.patient_id,
              doctor_name: order.doctor_id?.name || '-'
            },
            results: filteredResults.map(result => {
              const detail = orderDetails.find(d => d._id.toString() === result.detail_id.toString());
              return {
                _id: result._id,
                test_id: detail?.test_id?._id,
                test_name: detail?.test_id?.test_name || 'Unknown Test',
                test_code: detail?.test_id?.test_code,
                result_value: result.result_value,
                units: result.units,
                reference_range: result.reference_range,
                status: result.status,
                remarks: result.remarks,
                created_at: result.createdAt,
                staff_name: detail?.staff_id ? `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}` : null,
                component_name: result.component_name,
                detail_id: result.detail_id
              };
            })
          };
        }
      }
    }

    const allResults = Object.values(resultsByOrder);
    const totalResults = allResults.length;

    res.json({
      total: totalResults,
      page: parseInt(page),
      totalPages: Math.ceil(totalResults / parseInt(limit)),
      results: allResults.slice(0, parseInt(limit))
    });
  } catch (err) {
    console.error("Error fetching results:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get Tests Ready for Result Upload
 * @route   GET /api/staff/tests-for-upload
 * @access  Private (Staff)
 */
exports.getTestsForResultUpload = async (req, res) => {
  try {
    const staff_id = req.user._id;
    const { page = 1, limit = 50, patientName, testName } = req.query;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get ALL order details assigned to this staff (not just collected ones)
    // First, get OrderDetails that don't have results yet
    const existingResultDetailIds = await Result.distinct('detail_id', {
      detail_id: { $exists: true }
    });

    const orderDetails = await OrderDetails.find({
      staff_id: staff_id,
      status: { $in: ['collected', 'in_progress'] }, // Only tests that need result upload
      sample_collected: true, // Ensure sample has been collected
      _id: { $nin: existingResultDetailIds } // Exclude tests that already have results
    })
    .populate({
      path: 'order_id',
      populate: {
        path: 'patient_id',
        select: 'full_name patient_id phone_number email'
      }
    })
    .populate('test_id', 'test_name test_code price')
    .populate('staff_id', 'full_name employee_number username')
    .sort({ updatedAt: -1 })
    .skip(skip)
    .limit(parseInt(limit));

    // Filter by patient name and test name if provided
    let filteredDetails = orderDetails;

    if (patientName) {
      filteredDetails = filteredDetails.filter(detail => {
        const patient = detail.order_id?.patient_id;
        if (!patient) return false;
        const fullName = `${patient.full_name?.first || ''} ${patient.full_name?.last || ''}`.toLowerCase();
        return fullName.includes(patientName.toLowerCase());
      });
    }

    if (testName) {
      filteredDetails = filteredDetails.filter(detail => {
        const testNameField = detail.test_id?.test_name?.toLowerCase() || '';
        return testNameField.includes(testName.toLowerCase());
      });
    }

    // Get total count for pagination - tests that need result upload (excluding those with results)
    const totalCount = await OrderDetails.countDocuments({
      staff_id: staff_id,
      status: { $in: ['collected', 'in_progress'] },
      sample_collected: true,
      _id: { $nin: existingResultDetailIds }
    });

    // Format response
    const testsForUpload = filteredDetails.map(detail => ({
      detail_id: detail._id,
      test_id: detail.test_id?._id,
      test_name: detail.test_id?.test_name || 'Unknown Test',
      test_code: detail.test_id?.test_code || '',
      patient: detail.order_id?.patient_id ? {
        name: `${detail.order_id.patient_id.full_name?.first || ''} ${detail.order_id.patient_id.full_name?.last || ''}`.trim(),
        patient_id: detail.order_id.patient_id.patient_id,
        phone: detail.order_id.patient_id.phone_number,
        email: detail.order_id.patient_id.email
      } : null,
      order_date: detail.order_id?.order_date,
      collected_date: detail.sample_collected_date,
      status: detail.status,
      assigned_to: detail.staff_id ? {
        _id: detail.staff_id._id,
        name: `${detail.staff_id.full_name?.first || ''} ${detail.staff_id.full_name?.last || ''}`.trim(),
        employee_number: detail.staff_id.employee_number,
        username: detail.staff_id.username
      } : null
    }));

    res.json({
      total: totalCount,
      page: parseInt(page),
      totalPages: Math.ceil(totalCount / parseInt(limit)),
      tests: testsForUpload
    });

  } catch (err) {
    console.error("Error fetching tests for result upload:", err);
    res.status(500).json({ error: err.message });
  }
};
exports.getAllInvoices = async (req, res) => {
  try {
    const staff_id = req.user._id;
    const { page = 1, limit = 50, startDate, endDate, status, patientName } = req.query;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    let query = { owner_id: staff.owner_id };

    // Filter by date range if provided
    if (startDate || endDate) {
      query.invoice_date = {};
      if (startDate) query.invoice_date.$gte = new Date(startDate);
      if (endDate) query.invoice_date.$lte = new Date(endDate);
    }

    // Filter by payment status if provided
    if (status) {
      query.payment_status = status;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const invoices = await Invoice.find(query)
      .populate({
        path: 'order_id',
        populate: [
          { path: 'patient_id', select: 'full_name patient_id phone_number email' },
          { path: 'doctor_id', select: 'name' }
        ]
      })
      .sort({ invoice_date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Filter by patient name if provided
    let filteredInvoices = invoices;
    if (patientName) {
      filteredInvoices = invoices.filter(invoice => {
        if (invoice.order_id?.patient_id?.full_name) {
          const fullName = `${invoice.order_id.patient_id.full_name.first} ${invoice.order_id.patient_id.full_name.last}`.toLowerCase();
          return fullName.includes(patientName.toLowerCase());
        }
        return false;
      });
    }

    const total = await Invoice.countDocuments(query);

    const formattedInvoices = filteredInvoices.map(invoice => ({
      _id: invoice._id,
      invoice_id: invoice.invoice_id,
      invoice_date: invoice.invoice_date,
      due_date: invoice.due_date,
      total_amount: invoice.total_amount,
      payment_status: invoice.payment_status,
      payment_date: invoice.payment_date,
      payment_method: invoice.payment_method,
      notes: invoice.notes,
      order: invoice.order_id ? {
        _id: invoice.order_id._id,
        order_id: invoice.order_id.order_id,
        order_date: invoice.order_id.order_date,
        status: invoice.order_id.status,
        patient_name: invoice.order_id.patient_id ?
          `${invoice.order_id.patient_id.full_name.first} ${invoice.order_id.patient_id.full_name.last}` : 'Unknown Patient',
        patient_id: invoice.order_id.patient_id?.patient_id,
        doctor_name: invoice.order_id.doctor_id?.name || '-'
      } : null
    }));

    res.json({
      total: patientName ? formattedInvoices.length : total,
      page: parseInt(page),
      totalPages: Math.ceil((patientName ? formattedInvoices.length : total) / parseInt(limit)),
      invoices: formattedInvoices
    });
  } catch (err) {
    console.error("Error fetching invoices:", err);
    res.status(500).json({ error: err.message });
  }
};

// ✅ Get All Doctors (for order creation)
/**
 * @desc    Get all doctors for staff to assign to orders
 * @route   GET /api/staff/doctors
 * @access  Private (Staff)
 */
exports.getAllDoctors = async (req, res) => {
  try {
    const Doctor = require('../models/Doctor');
    // Return all doctors (doctors are global, not lab-specific)
    const doctors = await Doctor.find({})
      .select('doctor_id name specialty license_number phone_number email')
      .sort({ name: 1 });

    res.json({
      success: true,
      count: doctors.length,
      doctors: doctors.map(doctor => ({
        _id: doctor._id,
        doctor_id: doctor.doctor_id,
        name: `${doctor.name.first} ${doctor.name.last}`,
        full_name: doctor.name,
        specialty: doctor.specialty,
        license_number: doctor.license_number,
        phone_number: doctor.phone_number,
        email: doctor.email
      }))
    });
  } catch (err) {
    console.error("Error fetching doctors:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get Order Results Report (same as patient view)
 * @route   GET /api/staff/orders/:orderId/results
 * @access  Private (Staff)
 */
exports.getOrderResultsReport = async (req, res) => {
  try {
    const { orderId } = req.params;
    const staff_id = req.user._id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Verify order belongs to staff's lab
    const order = await Order.findOne({
      _id: orderId,
      owner_id: staff.owner_id
    })
      .populate('doctor_id', 'name')
      .populate('owner_id', 'lab_name name address phone_number')
      .populate('patient_id', 'full_name patient_id birthday gender phone_number email');

    if (!order) {
      return res.status(404).json({ message: '❌ Order not found or access denied' });
    }

    // Get order details with results
    const details = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code reference_range units')
      .populate('staff_id', 'full_name') // Populate staff information
      .sort({ createdAt: 1 });

    // Auto-assign unassigned tests to current staff
    const unassignedDetails = details.filter(detail => !detail.staff_id);
    if (unassignedDetails.length > 0) {
      // Update unassigned tests to assign them to current staff
      await OrderDetails.updateMany(
        { _id: { $in: unassignedDetails.map(d => d._id) } },
        { staff_id: staff_id }
      );

      // Refresh the details after assignment
      const updatedDetails = await OrderDetails.find({ order_id: order._id })
        .populate('test_id', 'test_name test_code reference_range units')
        .populate('staff_id', 'full_name')
        .sort({ createdAt: 1 });

      // Use updated details for the rest of the function
      details.length = 0;
      details.push(...updatedDetails);
    }

    // Get results for completed tests
    const detailIds = details
      .filter(d => d.status === 'completed')
      .map(d => d._id);
    const results = await Result.find({ detail_id: { $in: detailIds } });

    // Get components for tests that have them
    const resultsWithComponents = results.filter(r => r.has_components);
    const resultIds = resultsWithComponents.map(r => r._id);
    const ResultComponent = require('../models/ResultComponent');
    const components = await ResultComponent.find({ result_id: { $in: resultIds } })
      .populate('component_id')
      .sort({ 'component_id.display_order': 1 });

    // Combine details with results and components
    const resultsWithDetails = details.map(detail => {
      const result = detail.status === 'completed'
        ? results.find(r => r.detail_id.toString() === detail._id.toString())
        : null;

      let componentsForTest = [];
      if (result && result.has_components) {
        componentsForTest = components
          .filter(c => c.result_id.toString() === result._id.toString())
          .map(c => ({
            component_name: c.component_name,
            component_value: c.component_value,
            units: c.units,
            reference_range: c.reference_range,
            is_abnormal: c.is_abnormal,
            remarks: c.remarks
          }));
      }

      const testResult = result?.result_value || (detail.status === 'in_progress' ? 'In Progress' : 'Pending');

      return {
        detail_id: detail._id,
        test_name: detail.test_id?.test_name || 'Unknown Test',
        test_code: detail.test_id?.test_code || 'N/A',
        status: detail.status,
        test_result: testResult,
        units: result?.units || detail.test_id?.units || 'N/A',
        reference_range: detail.test_id?.reference_range || 'N/A',
        remarks: result?.remarks || null,
        createdAt: result?.createdAt || detail.createdAt,
        staff_name: detail.staff_id ? `${detail.staff_id.full_name.first} ${detail.staff_id.full_name.last}`.trim() : 'Unassigned',
        staff_id: detail.staff_id?._id || null,
        result: result || null,
        has_components: result?.has_components || false,
        components: componentsForTest
      };
    });

    // Get doctor name if available
    const doctorName = order.doctor_id?.name
      ? `Dr. ${order.doctor_id.name.first} ${order.doctor_id.name.middle || ''} ${order.doctor_id.name.last}`.trim()
      : null;

    // Get lab name and address if available
    const labName = order.owner_id?.lab_name || 'Medical Laboratory';
    const labAddress = order.owner_id?.address
      ? `${order.owner_id.address.street || ''}, ${order.owner_id.address.city || ''}, ${order.owner_id.address.state || ''} ${order.owner_id.address.postal_code || ''}`.trim().replace(/^,\s*/, '').replace(/,\s*$/, '')
      : null;
    const labPhone = order.owner_id?.phone_number || null;

    const patientInfo = order.is_patient_registered && order.patient_id
      ? {
          name: `${order.patient_id.full_name.first} ${order.patient_id.full_name.middle || ''} ${order.patient_id.full_name.last}`.trim(),
          patient_id: order.patient_id.patient_id,
          phone_number: order.patient_id.phone_number,
          email: order.patient_id.email,
          age: order.patient_id.birthday ? Math.floor((new Date() - new Date(order.patient_id.birthday)) / 31557600000) : null,
          gender: order.patient_id.gender
        }
      : order.temp_patient_info || { name: 'Walk-in Patient', patient_id: 'N/A', phone_number: 'Not provided', email: 'Not provided', age: null, gender: null };

    res.json({
      order: {
        order_id: order._id,
        order_date: order.order_date,
        doctor_name: doctorName,
        lab_name: labName,
        lab_address: labAddress,
        lab_phone: labPhone,
        status: order.status,
        patient_info: patientInfo
      },
      results: resultsWithDetails,
      count: resultsWithDetails.length
    });
  } catch (err) {
    console.error("Error fetching order results report:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get Invoice Details (same as patient view)
 * @route   GET /api/staff/invoices/:invoiceId/details
 * @access  Private (Staff)
 */
exports.getInvoiceDetails = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const staff_id = req.user._id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    const invoice = await Invoice.findOne({
      _id: invoiceId,
      owner_id: staff.owner_id
    })
      .populate({
        path: 'order_id',
        populate: [
          { path: 'patient_id', select: 'full_name patient_id email phone_number birthday gender' },
          { path: 'doctor_id', select: 'name' }
        ]
      })
      .populate('owner_id', 'lab_name name address phone_number email')
      .populate('items.test_id', 'test_name test_code');

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found or access denied" });
    }

    // Check if invoice has a valid order
    if (!invoice.order_id) {
      // If no order_id, try to provide invoice details using the invoice's items array
      // This handles cases where invoices exist without order references
      const subtotal = invoice.subtotal || invoice.items?.reduce((sum, item) => sum + (item.price || 0) * (item.quantity || 1), 0) || 0;
      const tax = 0; // No tax info stored in invoice
      const discount = invoice.discount || 0;
      const total = subtotal + tax - discount;

      // Get lab info
      const labInfo = {
        name: invoice.owner_id?.lab_name || invoice.owner_id?.name || 'Medical Laboratory',
        address: invoice.owner_id?.address
          ? `${invoice.owner_id.address.street || ''}, ${invoice.owner_id.address.city || ''}, ${invoice.owner_id.address.state || ''} ${invoice.owner_id.address.postal_code || ''}`.trim().replace(/^,\s*/, '').replace(/,\s*$/, '')
          : null,
        phone: invoice.owner_id?.phone_number,
        email: invoice.owner_id?.email
      };

      return res.json({
        success: true,
        invoice: {
          _id: invoice._id,
          invoice_id: invoice.invoice_id,
          invoice_date: invoice.invoice_date,
          due_date: null, // No due date stored
          payment_status: 'paid', // All invoices are paid
          payment_date: invoice.payment_date,
          payment_method: invoice.payment_method,
          notes: invoice.remarks,
          order_id: null,
          order_date: null
        },
        lab: labInfo,
        patient: { name: 'Unknown Patient', patient_id: 'N/A', email: null, phone: null, age: null, gender: null },
        doctor: null,
        tests: invoice.items?.map(item => ({
          test_name: item.test_id?.test_name || item.test_name || 'Unknown Test',
          test_code: item.test_id?.test_code || 'N/A',
          price: item.price || 0,
          status: 'completed' // Assume completed since invoice exists
        })) || [],
        totals: {
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: total,
          amount_paid: invoice.amount_paid || 0,
          balance_due: total - (invoice.amount_paid || 0)
        },
        warning: 'This invoice has no associated order. Some information may be limited.'
      });
    }

    // Get order details (tests)
    const details = await OrderDetails.find({ order_id: invoice.order_id._id })
      .populate('test_id', 'test_name test_code price');

    // Calculate totals
    // Use stored totals if available, otherwise calculate from order details
    const subtotal = invoice.subtotal || details.reduce((sum, d) => sum + (d.test_id?.price || 0), 0);
    const tax = 0; // No tax field in invoice model
    const discount = invoice.discount || 0;
    const total = invoice.total_amount || (subtotal + tax - discount);

    // Get patient info
    const patientInfo = invoice.order_id.patient_id
      ? {
          name: `${invoice.order_id.patient_id.full_name?.first || ''} ${invoice.order_id.patient_id.full_name?.last || ''}`.trim(),
          patient_id: invoice.order_id.patient_id.patient_id,
          email: invoice.order_id.patient_id.email,
          phone: invoice.order_id.patient_id.phone_number,
          age: invoice.order_id.patient_id.birthday ? Math.floor((new Date() - new Date(invoice.order_id.patient_id.birthday)) / 31557600000) : null,
          gender: invoice.order_id.patient_id.gender
        }
      : invoice.order_id.temp_patient_info || { name: 'Walk-in Patient', patient_id: 'N/A', email: null, phone: null, age: null, gender: null };

    // Get lab info
    const labInfo = {
      name: invoice.owner_id?.lab_name || invoice.owner_id?.name || 'Medical Laboratory',
      address: invoice.owner_id?.address
        ? `${invoice.owner_id.address.street || ''}, ${invoice.owner_id.address.city || ''}, ${invoice.owner_id.address.state || ''} ${invoice.owner_id.address.postal_code || ''}`.trim().replace(/^,\s*/, '').replace(/,\s*$/, '')
        : null,
      phone: invoice.owner_id?.phone_number,
      email: invoice.owner_id?.email
    };

    res.json({
      success: true,
      invoice: {
        _id: invoice._id,
        invoice_id: invoice.invoice_id,
        invoice_date: invoice.invoice_date,
        due_date: invoice.due_date,
        payment_status: 'paid', // All invoices are paid
        payment_date: invoice.payment_date,
        payment_method: invoice.payment_method,
        notes: invoice.notes,
        order_id: invoice.order_id._id,
        order_date: invoice.order_id.order_date
      },
      lab: labInfo,
      patient: patientInfo,
      doctor: invoice.order_id.doctor_id?.name
        ? `Dr. ${invoice.order_id.doctor_id.name.first || ''} ${invoice.order_id.doctor_id.name.middle || ''} ${invoice.order_id.doctor_id.name.last || ''}`.trim()
        : null,
      tests: details.map(d => ({
        test_name: d.test_id?.test_name || 'Unknown Test',
        test_code: d.test_id?.test_code || 'N/A',
        price: d.test_id?.price || 0,
        status: d.status
      })),
      totals: {
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        amount_paid: invoice.amount_paid || 0,
        balance_due: total - (invoice.amount_paid || 0)
      }
    });

  } catch (err) {
    console.error("Error fetching invoice details:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get Invoice by Order ID
 * @route   GET /api/staff/orders/:orderId/invoice
 * @access  Private (Staff)
 */
exports.getInvoiceByOrderId = async (req, res) => {
  try {
    const { orderId } = req.params;
    const staff_id = req.user._id;

    // Get staff to find their lab (owner_id)
    const staff = await Staff.findById(staff_id);
    if (!staff) {
      return res.status(404).json({ message: "Staff not found" });
    }

    // Find invoice for this order
    const invoice = await Invoice.findOne({
      order_id: orderId,
      owner_id: staff.owner_id
    });

    if (!invoice) {
      return res.status(404).json({ message: "No invoice found for this order" });
    }

    res.json({
      success: true,
      invoice: {
        _id: invoice._id,
        invoice_id: invoice.invoice_id
      }
    });

  } catch (err) {
    console.error("Error fetching invoice by order ID:", err);
    res.status(500).json({ error: err.message });
  }
};

module.exports = exports;
