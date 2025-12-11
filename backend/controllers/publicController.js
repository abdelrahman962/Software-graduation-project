const Order = require("../models/Order");
const OrderDetails = require("../models/OrderDetails");
const Test = require("../models/Test");
const LabOwner = require("../models/Owner");
const Notification = require("../models/Notification");
const Feedback = require("../models/Feedback");
const Patient = require("../models/Patient");
const Doctor = require("../models/Doctor");
const Staff = require("../models/Staff");
const Admin = require("../models/Admin");
const jwt = require('jsonwebtoken');
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

/**
 * @desc    Get system feedback for marketing pages
 * @route   GET /api/public/feedback/system
 * @access  Public
 */
exports.getSystemFeedback = async (req, res) => {
  try {
    const { limit = 20, minRating = 4, role } = req.query;

    // Build query filter
    const query = {
      target_type: 'system',
      rating: { $gte: parseInt(minRating) }
    };

    // Filter by role if specified
    if (role && ['Patient', 'Staff', 'Owner', 'Doctor'].includes(role)) {
      query.user_model = role;
    }

    const feedback = await Feedback.find(query)
    .populate({
      path: 'user_id',
      select: 'full_name lab_name username'
    })
    .sort({ rating: -1, createdAt: -1 })
    .limit(parseInt(limit))
    .select('rating message user_id user_model is_anonymous createdAt')
    .lean();

    // Transform the data with proper user information
    const transformedFeedback = feedback.map(item => {
      let userName = 'Anonymous User';
      
      if (!item.is_anonymous && item.user_id) {
        if (item.user_model === 'Owner' && item.user_id.lab_name) {
          userName = item.user_id.lab_name;
        } else if (item.user_id.full_name) {
          userName = `${item.user_id.full_name.first} ${item.user_id.full_name.last}`;
        } else if (item.user_id.username) {
          userName = item.user_id.username;
        }
      }

      return {
        _id: item._id,
        user_id: item.is_anonymous ? null : item.user_id?._id,
        user_model: item.user_model,
        user_role: item.user_model, // For frontend display
        user_name: userName,
        target_type: 'system',
        target_id: null,
        rating: item.rating,
        message: item.message,
        is_anonymous: item.is_anonymous,
        createdAt: item.createdAt,
        updatedAt: item.createdAt
      };
    });

    // Group by role for statistics
    const roleStats = feedback.reduce((acc, item) => {
      acc[item.user_model] = (acc[item.user_model] || 0) + 1;
      return acc;
    }, {});

    res.json({
      success: true,
      count: transformedFeedback.length,
      feedback: transformedFeedback,
      statistics: {
        total: transformedFeedback.length,
        by_role: roleStats,
        average_rating: feedback.length > 0 
          ? (feedback.reduce((sum, f) => sum + f.rating, 0) / feedback.length).toFixed(1)
          : 0
      }
    });
  } catch (err) {
    console.error("Error fetching system feedback:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Submit contact form for laboratory owners interested in the system
 * @route   POST /api/public/contact
 * @access  Public
 */
exports.submitContactForm = async (req, res) => {
  try {
    const { name, email, phone, lab_name, message } = req.body;

    // Validate required fields
    if (!name || !email || !lab_name || !message) {
      return res.status(400).json({
        message: "Name, email, laboratory name, and message are required"
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: "Please provide a valid email address" });
    }

    // Create contact inquiry record (you might want to create a Contact model for this)
    // For now, we'll just send an email notification to the admin

    // Send email notification to admin
    const adminEmailSubject = `New Contact Inquiry: ${lab_name}`;
    const adminEmailBody = `
      <h2>New Laboratory Contact Inquiry</h2>
      <p><strong>Contact Person:</strong> ${name}</p>
      <p><strong>Email:</strong> ${email}</p>
      <p><strong>Phone:</strong> ${phone || 'Not provided'}</p>
      <p><strong>Laboratory Name:</strong> ${lab_name}</p>
      <p><strong>Message:</strong></p>
      <p>${message.replace(/\n/g, '<br>')}</p>
      <hr>
      <p><em>This inquiry was submitted through the MedLab System contact form.</em></p>
    `;

    // Send email to admin (you'll need to configure admin email)
    try {
      await sendEmail(process.env.ADMIN_EMAIL || 'admin@medlabsystem.com', adminEmailSubject, adminEmailBody);
    } catch (emailError) {
      console.error('Failed to send admin notification email:', emailError);
      // Don't fail the request if email fails, just log it
    }

    // Send confirmation email to the contact person
    const confirmationSubject = 'Thank you for your interest in MedLab System';
    const confirmationBody = `
      <h2>Thank you for contacting us!</h2>
      <p>Dear ${name},</p>
      <p>Thank you for your interest in MedLab System. We have received your inquiry about implementing our laboratory management system for ${lab_name}.</p>
      <p>Our team will review your message and contact you within 24-48 hours to discuss your specific needs and how we can help transform your laboratory operations.</p>
      <p><strong>Your message:</strong></p>
      <p>${message.replace(/\n/g, '<br>')}</p>
      <br>
      <p>Best regards,<br>The MedLab System Team</p>
    `;

    try {
      await sendEmail(email, confirmationSubject, confirmationBody);
    } catch (emailError) {
      console.error('Failed to send confirmation email:', emailError);
    }

    res.status(200).json({
      message: "Contact form submitted successfully. We will contact you soon!",
      success: true
    });

  } catch (err) {
    console.error("Error submitting contact form:", err);
    res.status(500).json({ error: err.message });
  }
};

/**
 * @desc    Unified Login - checks all user types in one request
 * @route   POST /api/public/login
 * @access  Public
 */
exports.unifiedLogin = async (req, res, next) => {
  try {
    const { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ message: '⚠️ Username and password are required' });
    }

    // Try each user type in order: Patient, Doctor, Staff, Owner, Admin
    const userTypes = [
      {
        model: Patient,
        role: 'patient',
        route: '/patient-dashboard',
        fields: {
          _id: 1,
          patient_id: 1,
          full_name: 1,
          identity_number: 1,
          birthday: 1,
          gender: 1,
          insurance_provider: 1,
          insurance_number: 1,
          email: 1,
          username: 1
        }
      },
      {
        model: Doctor,
        role: 'doctor',
        route: '/doctor-dashboard',
        fields: {
          _id: 1,
          doctor_id: 1,
          full_name: 1,
          specialization: 1,
          license_number: 1,
          email: 1,
          username: 1
        }
      },
      {
        model: Staff,
        role: 'staff',
        route: '/staff/dashboard',
        fields: {
          _id: 1,
          full_name: 1,
          employee_number: 1,
          position: 1,
          email: 1,
          username: 1,
          owner_id: 1
        }
      },
      {
        model: LabOwner,
        role: 'owner',
        route: '/owner/dashboard',
        fields: {
          _id: 1,
          lab_name: 1,
          owner_name: 1,
          email: 1,
          username: 1,
          phone_number: 1,
          license_number: 1,
          status: 1
        }
      },
      {
        model: Admin,
        role: 'admin',
        route: '/admin/dashboard',
        fields: {
          _id: 1,
          full_name: 1,
          email: 1,
          username: 1
        }
      }
    ];

    // Normalize username for staff (lowercase, spaces to dots)
    const normalizedUsername = username.replace(/\s+/g, '.').toLowerCase();

    for (const userType of userTypes) {
      // For staff, use normalized username
      const searchUsername = userType.role === 'staff' ? normalizedUsername : username;
      
      const user = await userType.model.findOne({
        $or: [{ username: searchUsername }, { email: username }]
      });

      if (user) {
        // Check password
        const isMatch = await user.comparePassword(password);
        if (isMatch) {
          // Update last login if field exists
          if (user.last_login !== undefined) {
            user.last_login = new Date();
            await user.save();
          }

          // Generate JWT token
          const tokenPayload = {
            _id: user._id,
            role: userType.role,
            username: user.username
          };

          // Add role-specific IDs
          if (userType.role === 'patient' && user.patient_id) {
            tokenPayload.patient_id = user.patient_id;
          } else if (userType.role === 'doctor' && user.doctor_id) {
            tokenPayload.doctor_id = user.doctor_id;
          } else if (userType.role === 'staff' && user.owner_id) {
            tokenPayload.owner_id = user.owner_id;
          }

          const token = jwt.sign(
            tokenPayload,
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
          );

          // Prepare user data (remove password and other sensitive fields)
          const userData = {};
          Object.keys(userType.fields).forEach(field => {
            if (user[field] !== undefined) {
              userData[field] = user[field];
            }
          });

          return res.json({
            message: '✅ Login successful',
            token,
            role: userType.role,
            route: userType.route,
            user: userData
          });
        }
      }
    }

    // If we get here, no valid credentials were found
    return res.status(401).json({ message: '❌ Invalid credentials' });

  } catch (err) {
    next(err);
  }
};
