const Order = require("../models/Order");
const OrderDetails = require("../models/OrderDetails");
const Test = require("../models/Test");
const LabOwner = require("../models/Owner");
const Notification = require("../models/Notification");

/**
 * @desc    Patient submits registration form with personal info and test orders
 * @route   POST /api/public/submit-registration
 * @access  Public
 */
exports.submitRegistration = async (req, res) => {
  try {
    const { 
      lab_id,
      full_name, 
      identity_number, 
      birthday, 
      gender, 
      phone_number, 
      email, 
      address,
      social_status,
      insurance_provider,
      insurance_number,
      test_ids,
      remarks 
    } = req.body;

    // Validate required fields
    if (!lab_id) {
      return res.status(400).json({ message: "Lab selection is required" });
    }

    if (!full_name || !full_name.first || !full_name.last) {
      return res.status(400).json({ message: "Full name (first and last) is required" });
    }

    if (!identity_number || !birthday || !gender || !phone_number || !email || !address) {
      return res.status(400).json({ message: "All personal information fields are required" });
    }

    if (!test_ids || !Array.isArray(test_ids) || test_ids.length === 0) {
      return res.status(400).json({ message: "At least one test must be selected" });
    }

    // Verify lab exists
    const lab = await LabOwner.findById(lab_id);
    if (!lab) {
      return res.status(404).json({ message: "Lab not found" });
    }

    // Verify all tests exist and belong to this lab
    const tests = await Test.find({ 
      _id: { $in: test_ids },
      owner_id: lab_id 
    });

    if (tests.length !== test_ids.length) {
      return res.status(404).json({ message: "One or more tests not found or not available for this lab" });
    }

    // Generate unique barcode
    const barcode = `ORD-${Date.now()}`;

    // Create pending order with patient info
    const order = await Order.create({
      temp_patient_info: {
        full_name,
        identity_number,
        email,
        phone_number,
        birthday,
        gender,
        address,
        social_status,
        insurance_provider,
        insurance_number
      },
      order_date: new Date(),
      status: 'pending', // Pending until staff registers the patient
      remarks: remarks || null,
      barcode,
      owner_id: lab_id,
      is_patient_registered: false // Patient not yet registered
    });

    // Create order details for each test
    const orderDetailsData = tests.map(test => ({
      order_id: order._id,
      test_id: test._id,
      status: 'pending',
      sample_collected: false
    }));

    await OrderDetails.insertMany(orderDetailsData);

    // Calculate total cost
    const totalCost = tests.reduce((sum, test) => sum + (test.price || 0), 0);

    // Create notification for lab staff/owner
    await Notification.create({
      receiver_id: lab_id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'New Registration Request',
      message: `New patient registration request from ${full_name.first} ${full_name.last}. Order ${barcode} with ${tests.length} test(s) waiting for staff approval.`,
      related_id: order._id
    });

    res.status(201).json({
      success: true,
      message: "✅ Registration submitted successfully! Please visit the lab for verification.",
      registration: {
        order_id: order._id,
        barcode,
        lab_name: lab.lab_name,
        patient_name: `${full_name.first} ${full_name.last}`,
        email,
        phone_number,
        tests_ordered: tests.map(t => ({
          test_name: t.test_name,
          test_code: t.test_code,
          price: t.price
        })),
        total_cost: totalCost,
        tests_count: tests.length,
        status: "pending",
        next_steps: [
          "Visit the lab with your ID",
          "Show your registration barcode to staff",
          "Staff will verify your information and create your account",
          "You'll receive your account credentials via email"
        ]
      }
    });

  } catch (err) {
    console.error("Error submitting registration:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get list of available labs
 * @route   GET /api/public/labs
 * @access  Public
 */
exports.getAvailableLabs = async (req, res) => {
  try {
    // Get only approved and active labs
    const labs = await LabOwner.find({ 
      status: 'approved',
      is_active: true 
    })
    .select('lab_name email phone_number address subscription_end_date')
    .lean();

    res.json({
      success: true,
      count: labs.length,
      labs: labs.map(lab => ({
        _id: lab._id,
        lab_name: lab.lab_name,
        email: lab.email,
        phone_number: lab.phone_number,
        address: lab.address,
        subscription_active: lab.subscription_end_date > new Date()
      }))
    });

  } catch (err) {
    console.error("Error fetching labs:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Get available tests for a specific lab
 * @route   GET /api/public/labs/:labId/tests
 * @access  Public
 */
exports.getLabTests = async (req, res) => {
  try {
    const { labId } = req.params;

    // Verify lab exists and is active
    const lab = await LabOwner.findOne({ 
      _id: labId,
      status: 'approved',
      is_active: true 
    });

    if (!lab) {
      return res.status(404).json({ message: "Lab not found or inactive" });
    }

    // Get active tests for this lab
    const tests = await Test.find({ 
      owner_id: labId,
      is_active: true 
    })
    .select('test_code test_name sample_type price turnaround_time units reference_range')
    .sort({ test_name: 1 })
    .lean();

    res.json({
      success: true,
      lab: {
        _id: lab._id,
        lab_name: lab.lab_name
      },
      count: tests.length,
      tests: tests.map(test => ({
        _id: test._id,
        test_code: test.test_code,
        test_name: test.test_name,
        sample_type: test.sample_type,
        price: test.price,
        turnaround_time: test.turnaround_time,
        units: test.units,
        reference_range: test.reference_range
      }))
    });

  } catch (err) {
    console.error("Error fetching lab tests:", err);
    res.status(500).json({ error: err.message });
  }
};
