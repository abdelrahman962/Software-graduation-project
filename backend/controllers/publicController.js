const Order = require("../models/Order");
const OrderDetails = require("../models/OrderDetails");
const Test = require("../models/Test");
const LabOwner = require("../models/Owner");
const Notification = require("../models/Notification");
const LabBranch = require("../models/LabBranch");
const sendEmail = require("../utils/sendEmail");
const sendSMS = require("../utils/sendSMS");

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

    // Generate registration token for account creation
    const registrationToken = Order.generateRegistrationToken();
    const tokenExpiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    // Create pending order with patient info (no barcode yet)
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
      status: 'pending', // Pending until patient creates account
      remarks: remarks || null,
      owner_id: lab_id,
      is_patient_registered: false,
      registration_token: registrationToken,
      registration_token_expires: tokenExpiry
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
      message: `New patient registration request from ${full_name.first} ${full_name.last}. Order with ${tests.length} test(s) pending account creation.`,
      related_id: order._id
    });

    // Generate account creation link
    const registrationLink = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/register/complete?token=${registrationToken}`;

    // Send email with registration link
    const emailSubject = `Complete Your Account Registration - ${lab.lab_name}`;
    const emailMessage = `
Hello ${full_name.first} ${full_name.last},

Thank you for choosing ${lab.lab_name}!

Your test order has been submitted successfully. To complete your registration and access your account, please click the link below:

${registrationLink}

Order Details:
- Tests Ordered: ${tests.length}
- Total Cost: ${totalCost} ILS
- Lab: ${lab.lab_name}

This link will expire in 7 days.

Next Steps:
1. Click the link above to create your account
2. Visit the lab with your ID for sample collection
3. Track your results online after processing

If you have any questions, please contact us at ${lab.phone_number}

Best regards,
${lab.lab_name}
    `;

    await sendEmail(email, emailSubject, emailMessage);

    // Send SMS with registration link
    const smsMessage = `Hello ${full_name.first}! Complete your registration at ${lab.lab_name}: ${registrationLink}. Tests: ${tests.length}, Total: ${totalCost} ILS. Link expires in 7 days.`;
    await sendSMS(phone_number, smsMessage);

    res.status(201).json({
      success: true,
      message: "✅ Registration submitted successfully! Check your email and SMS for account creation link.",
      registration: {
        order_id: order._id,
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
          "Check your email and SMS for account creation link",
          "Click the link to create your account",
          "Visit the lab with your ID for sample collection",
          "Track your results online after processing"
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

// ============================================================================
// LAB BRANCH SEARCH ENDPOINTS
// ============================================================================

/**
 * @desc    Get all available lab branches with pagination and filters
 * @route   GET /api/public/branches/all
 * @access  Public
 */
exports.getAllAvailableBranches = async (req, res) => {
  try {
    const { page = 1, limit = 20, city, state, services, search } = req.query;
    
    let query = { is_active: true };
    
    // Filter by city
    if (city) {
      query['location.city'] = new RegExp(city, 'i');
    }
    
    // Filter by state
    if (state) {
      query['location.state'] = new RegExp(state, 'i');
    }
    
    // Filter by services offered
    if (services) {
      query.services_offered = { 
        $in: services.split(',').map(s => s.trim()) 
      };
    }
    
    // Search by branch name or location
    if (search) {
      query.$or = [
        { branch_name: new RegExp(search, 'i') },
        { 'location.city': new RegExp(search, 'i') },
        { 'location.street': new RegExp(search, 'i') }
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const branches = await LabBranch.find(query)
      .populate('owner_id', 'name phone_number email is_active status')
      .skip(skip)
      .limit(parseInt(limit))
      .sort({ created_at: -1 });

    // Filter to only show branches with active, approved owners
    const activeBranches = branches.filter(
      b => b.owner_id?.is_active && b.owner_id?.status === 'approved'
    );
    
    // Get total count for pagination
    const totalCount = await LabBranch.countDocuments(query);

    res.json({ 
      success: true,
      branches: activeBranches, 
      count: activeBranches.length,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        pages: Math.ceil(totalCount / parseInt(limit))
      }
    });
  } catch (err) {
    console.error("Error fetching branches:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Find nearest lab branches based on GPS coordinates
 * @route   GET /api/public/branches/nearest
 * @access  Public
 */
exports.findNearestBranches = async (req, res) => {
  try {
    const { latitude, longitude, maxDistance = 50, limit = 10 } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ 
        message: 'Latitude and longitude are required' 
      });
    }

    const lat = parseFloat(latitude);
    const lon = parseFloat(longitude);

    // Find branches using MongoDB geospatial query
    const branches = await LabBranch.aggregate([
      {
        $geoNear: {
          near: {
            type: 'Point',
            coordinates: [lon, lat]
          },
          distanceField: 'distance',
          maxDistance: parseFloat(maxDistance) * 1000, // Convert km to meters
          spherical: true,
          query: { is_active: true }
        }
      },
      {
        $limit: parseInt(limit)
      },
      {
        $lookup: {
          from: 'labowners',
          localField: 'owner_id',
          foreignField: '_id',
          as: 'owner'
        }
      },
      {
        $unwind: '$owner'
      },
      {
        $match: {
          'owner.is_active': true,
          'owner.status': 'approved'
        }
      },
      {
        $project: {
          branch_name: 1,
          branch_code: 1,
          location: 1,
          contact: 1,
          operating_hours: 1,
          services_offered: 1,
          distance: { $divide: ['$distance', 1000] }, // Convert to km
          'owner.name': 1,
          'owner.phone_number': 1,
          'owner.email': 1
        }
      }
    ]);

    res.json({ 
      success: true,
      branches, 
      count: branches.length,
      searchLocation: { latitude: lat, longitude: lon }
    });
  } catch (err) {
    console.error("Error finding nearest branches:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Search branches by city, state, or services
 * @route   GET /api/public/branches/search
 * @access  Public
 */
exports.searchBranches = async (req, res) => {
  try {
    const { city, state, services } = req.query;
    
    let query = { is_active: true };
    
    if (city) {
      query['location.city'] = new RegExp(city, 'i');
    }
    
    if (state) {
      query['location.state'] = new RegExp(state, 'i');
    }
    
    if (services) {
      query.services_offered = { 
        $in: services.split(',').map(s => s.trim()) 
      };
    }

    const branches = await LabBranch.find(query)
      .populate('owner_id', 'name phone_number email is_active status')
      .limit(50);

    // Filter to only show branches with active, approved owners
    const activeBranches = branches.filter(
      b => b.owner_id?.is_active && b.owner_id?.status === 'approved'
    );

    res.json({ 
      success: true,
      branches: activeBranches, 
      count: activeBranches.length 
    });
  } catch (err) {
    console.error("Error searching branches:", err);
    res.status(500).json({ error: err.message });
  }
};

// ============================================================================
// ACCOUNT REGISTRATION ENDPOINTS
// ============================================================================

/**
 * @desc    Verify registration token and get order details
 * @route   GET /api/public/register/verify/:token
 * @access  Public
 */
exports.verifyRegistrationToken = async (req, res) => {
  try {
    const { token } = req.params;

    const order = await Order.findOne({
      registration_token: token,
      registration_token_expires: { $gt: new Date() },
      is_patient_registered: false
    }).populate('owner_id', 'lab_name phone_number email');

    if (!order) {
      return res.status(400).json({ 
        success: false,
        message: "Invalid or expired registration token" 
      });
    }

    // Get tests for this order
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price');

    res.json({
      success: true,
      registration_data: {
        order_id: order._id,
        lab: {
          name: order.owner_id.lab_name,
          phone: order.owner_id.phone_number,
          email: order.owner_id.email
        },
        patient_info: order.temp_patient_info,
        tests: orderDetails.map(od => ({
          test_name: od.test_id.test_name,
          test_code: od.test_id.test_code,
          price: od.test_id.price
        })),
        total_cost: orderDetails.reduce((sum, od) => sum + (od.test_id.price || 0), 0)
      }
    });
  } catch (err) {
    console.error("Error verifying registration token:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Complete patient registration using token
 * @route   POST /api/public/register/complete
 * @access  Public
 */
exports.completeRegistration = async (req, res) => {
  try {
    const { token, username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ 
        message: "Username and password are required" 
      });
    }

    // Find order with valid token
    const order = await Order.findOne({
      registration_token: token,
      registration_token_expires: { $gt: new Date() },
      is_patient_registered: false
    });

    if (!order) {
      return res.status(400).json({ 
        message: "Invalid or expired registration token" 
      });
    }

    const Patient = require('../models/Patient');
    const bcrypt = require('bcrypt');

    // Check if username already exists
    const existingUser = await Patient.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ 
        message: "Username already exists. Please choose another." 
      });
    }

    // Check if email already registered
    const existingEmail = await Patient.findOne({ 
      email: order.temp_patient_info.email 
    });
    if (existingEmail) {
      return res.status(400).json({ 
        message: "Email already registered. Please login instead." 
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Generate unique patient ID
    const lastPatient = await Patient.findOne().sort({ patient_id: -1 });
    const newPatientId = lastPatient ? parseInt(lastPatient.patient_id) + 1 : 1000;

    // Create patient account
    const patient = await Patient.create({
      patient_id: newPatientId.toString(),
      username,
      password: hashedPassword,
      full_name: order.temp_patient_info.full_name,
      identity_number: order.temp_patient_info.identity_number,
      birthday: order.temp_patient_info.birthday,
      gender: order.temp_patient_info.gender,
      phone_number: order.temp_patient_info.phone_number,
      email: order.temp_patient_info.email,
      address: order.temp_patient_info.address,
      social_status: order.temp_patient_info.social_status,
      insurance_provider: order.temp_patient_info.insurance_provider,
      insurance_number: order.temp_patient_info.insurance_number,
      is_active: true
    });

    // Link order to patient
    await Order.findByIdAndUpdate(order._id, {
      patient_id: patient._id,
      is_patient_registered: true,
      registration_token: null, // Clear token after use
      registration_token_expires: null
    });

    // Send welcome email
    const welcomeSubject = `Welcome to ${order.owner_id?.lab_name || 'MedLab System'}`;
    const welcomeMessage = `
Hello ${patient.full_name.first},

Your account has been successfully created!

Login Credentials:
- Username: ${username}
- Patient ID: ${newPatientId}

You can now:
- Login to track your test results
- View your order history
- Schedule appointments

Please visit the lab with your ID for sample collection.

Best regards,
MedLab System
    `;

    await sendEmail(patient.email, welcomeSubject, welcomeMessage);

    // Notify lab owner
    await Notification.create({
      receiver_id: order.owner_id,
      receiver_model: 'Owner',
      type: 'system',
      title: 'Patient Account Created',
      message: `${patient.full_name.first} ${patient.full_name.last} has completed registration. Ready for sample collection.`,
      related_id: order._id
    });

    res.status(201).json({
      success: true,
      message: "✅ Account created successfully! Please login with your credentials.",
      patient: {
        patient_id: newPatientId,
        username,
        full_name: patient.full_name,
        email: patient.email
      }
    });
  } catch (err) {
    console.error("Error completing registration:", err);
    res.status(500).json({ error: err.message });
  }
};
