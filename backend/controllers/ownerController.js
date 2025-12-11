// Helper: Calculate tiered subscription fee
async function calculateTieredFee(ownerId) {
  const patientCount = await Patient.countDocuments({ owner_id: ownerId });

  // Patient fee
  let patientFee = 0;
  if (patientCount <= 500) patientFee = 50;
  else if (patientCount > 500 && patientCount <= 2000) patientFee = 100;
  else if (patientCount > 2000) patientFee = 200;

  return {
    total: patientFee,
    patientFee,
    patientCount
  };
}
const LabOwner = require('../models/Owner');
const Staff = require('../models/Staff');
const Patient = require('../models/Patient');
const Device = require('../models/Device');
const Test = require('../models/Test');
const Order = require('../models/Order');
const OrderDetails = require('../models/OrderDetails');
const Invoice = require('../models/Invoices');
const Notification = require('../models/Notification');
const AuditLog = require('../models/AuditLog');
const Feedback = require('../models/Feedback');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// ==================== AUTHENTICATION ====================

/**
 * @desc    Lab Owner Login
 * @route   POST /api/owner/login
 * @access  Public
 */
exports.login = async (req, res, next) => {
  try {
    let { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ success: false, error: '⚠️ Username and password are required' });
    }

    // Normalize username (remove spaces, convert to lowercase)
    const normalizedUsername = username.replace(/\s+/g, '.').toLowerCase().trim();

    // Find owner by username or email
    const owner = await LabOwner.findOne({ $or: [{ username: normalizedUsername }, { email: username }] });
    if (!owner) {
      return res.status(401).json({ success: false, error: '❌ Invalid credentials' });
    }

    // Check if owner is approved and active
    if (owner.status !== 'approved') {
      return res.status(403).json({ success: false, error: '⚠️ Account is not approved yet. Please wait for admin approval.' });
    }

    if (!owner.is_active) {
      return res.status(403).json({ success: false, error: '⚠️ Account is inactive. Please contact support.' });
    }

    // Compare password
    const isMatch = await owner.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ success: false, error: '❌ Invalid credentials' });
    }

    // Check subscription status and calculate days remaining
    let subscriptionWarning = null;
    let subscriptionExpired = false;
    
    if (owner.subscription_end) {
      const today = new Date();
      const endDate = new Date(owner.subscription_end);
      const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

      if (daysRemaining < 0) {
        subscriptionExpired = true;
        subscriptionWarning = `⚠️ Your subscription expired ${Math.abs(daysRemaining)} days ago. Limited access - please renew immediately.`;
      } else if (daysRemaining <= 7) {
        subscriptionWarning = `⚠️ Your subscription expires in ${daysRemaining} day(s). Please renew soon to avoid service interruption.`;
      } else if (daysRemaining <= 30) {
        subscriptionWarning = `ℹ️ Your subscription expires in ${daysRemaining} days.`;
      }
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        _id: owner._id, 
        owner_id: owner.owner_id,
        role: 'owner',
        username: owner.username,
        subscription_expired: subscriptionExpired
      },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Calculate dynamic fee
    const feeInfo = await calculateTieredFee(owner._id);
    res.json({
      success: true,
      message: subscriptionExpired 
        ? '⚠️ Login successful - SUBSCRIPTION EXPIRED' 
        : '✅ Login successful',
      token,
      owner: {
        _id: owner._id,
        owner_id: owner.owner_id,
        name: owner.name,
        email: owner.email,
        username: owner.username,
        subscription_end: owner.subscription_end,
        subscription_expired: subscriptionExpired,
        subscriptionFee: feeInfo.total,
        feeBreakdown: feeInfo
      },
      ...(subscriptionWarning && { warning: subscriptionWarning })
    });

  } catch (err) {
    next(err);
  }
};

// ==================== REQUEST ACCESS ====================
/**
 * @desc    Lab Owner requests access to use the system
 * @route   POST /api/owner/request-access
 * @access  Public
 */
exports.requestAccess = async (req, res, next) => {
  try {
    const { first_name, middle_name, last_name, identity_number, birthday, gender, social_status, phone, address, qualification, profession_license, bank_iban, email, username, password, selected_plan } = req.body;

    if (!first_name || !last_name || !identity_number || !email || !username || !password)
      return res.status(400).json({ success: false, error: '⚠️ Missing required fields' });

    const existingOwner = await LabOwner.findOne({ $or: [{ email }, { username }, { identity_number }] });
    if (existingOwner) return res.status(400).json({ success: false, error: '⚠️ Lab Owner with provided email, username, or ID already exists' });

    // Set subscription fee based on selected plan
    let subscriptionFee = 100; // Default
    if (selected_plan === 'Professional') subscriptionFee = 200;
    else if (selected_plan === 'Enterprise') subscriptionFee = 400;

    const hashedPassword = await bcrypt.hash(password, 10);
    const owner_id = `OWN-${Date.now()}`;

    const newRequest = await LabOwner.create({
      name: { first: first_name, middle: middle_name || '', last: last_name },
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number: phone,
      address,
      qualification,
      profession_license,
      bank_iban,
      email,
      username,
      password: hashedPassword,
      owner_id,
      date_subscription: null,
      status: 'pending',
      admin_id: null,
      is_active: false,
      subscriptionFee
    });

    const admins = await Admin.find({});
    const notifications = admins.map(admin => ({
      sender_id: newRequest._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      title: 'New Lab Owner Request',
      message: `Lab Owner ${first_name} ${last_name} has requested access to the system.${selected_plan ? ` Selected Plan: ${selected_plan} (\$${subscriptionFee}/month)` : ''}`
    }));
    await Notification.insertMany(notifications);

    res.status(201).json({
      success: true,
      message: '✅ Lab Owner request submitted successfully. Waiting for admin approval.',
      labOwner: newRequest
    });

  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Owner Profile
 * @route   GET /api/owner/profile
 * @access  Private (Owner)
 */
exports.getProfile = async (req, res, next) => {
  try {
    const owner = await LabOwner.findById(req.user._id).select('-password');
    
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Calculate days until subscription expires
    let subscriptionStatus = null;
    if (owner.subscription_end) {
      const today = new Date();
      const endDate = new Date(owner.subscription_end);
      const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

      if (daysRemaining < 0) {
        subscriptionStatus = {
          status: 'expired',
          daysRemaining: 0,
          expiredDays: Math.abs(daysRemaining),
          message: `⚠️ Your subscription expired ${Math.abs(daysRemaining)} days ago. Please contact admin to renew.`
        };
      } else if (daysRemaining <= 7) {
        subscriptionStatus = {
          status: 'expiring_soon',
          daysRemaining,
          message: `⚠️ Your subscription will expire in ${daysRemaining} day(s). Please contact admin to renew.`
        };
      } else if (daysRemaining <= 30) {
        subscriptionStatus = {
          status: 'expiring_within_month',
          daysRemaining,
          message: `ℹ️ Your subscription will expire in ${daysRemaining} days.`
        };
      } else {
        subscriptionStatus = {
          status: 'active',
          daysRemaining,
          message: `✅ Your subscription is active until ${endDate.toDateString()}.`
        };
      }
    }

    // Calculate dynamic fee
    const feeInfo = await calculateTieredFee(owner._id);
    res.json({
      ...owner.toObject(),
      subscriptionStatus,
      subscriptionFee: feeInfo.total,
      feeBreakdown: feeInfo
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Owner Profile
 * @route   PUT /api/owner/profile
 * @access  Private (Owner)
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const { phone_number, address, email, bank_iban } = req.body;

    const owner = await LabOwner.findById(req.user._id);
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Update allowed fields
    if (phone_number) owner.phone_number = phone_number;
    if (address) {
      // Convert string address to proper format matching addressSchema.js
      if (typeof address === 'string') {
        const addressParts = address.split(',').map(part => part.trim());
        owner.address = {
          street: addressParts[0] || '',
          city: addressParts[1] || '',
          country: addressParts[2] || 'Palestine'
        };
      } else {
        // Ensure only schema fields are used
        owner.address = {
          street: address.street || '',
          city: address.city || '',
          country: address.country || 'Palestine'
        };
      }
    }
    if (email) owner.email = email;
    if (bank_iban) owner.bank_iban = bank_iban;

    await owner.save();

    res.json({ 
      message: '✅ Profile updated successfully', 
      owner: await LabOwner.findById(owner._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Change Password
 * @route   PUT /api/owner/change-password
 * @access  Private (Owner)
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, error: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, error: '⚠️ New password must be at least 6 characters' });
    }

    const owner = await LabOwner.findById(req.user._id);
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Verify current password
    const isMatch = await owner.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ success: false, error: '❌ Current password is incorrect' });
    }

    // Update password
    owner.password = await bcrypt.hash(newPassword, 10);
    await owner.save();

    res.json({ success: true, message: '✅ Password changed successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== STAFF MANAGEMENT ====================

/**
 * @desc    Get All Staff Members
 * @route   GET /api/owner/staff
 * @access  Private (Owner)
 */
exports.getAllStaff = async (req, res, next) => {
  try {
    const staff = await Staff.find({ owner_id: req.user._id }).select('-password');
    res.json({ count: staff.length, staff });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Staff Member
 * @route   GET /api/owner/staff/:staffId
 * @access  Private (Owner)
 */
exports.getStaffById = async (req, res, next) => {
  try {
    const staff = await Staff.findOne({ 
      _id: req.params.staffId, 
      owner_id: req.user._id 
    }).select('-password');

    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    res.json(staff);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Staff Member
 * @route   POST /api/owner/staff
 * @access  Private (Owner)
 */
exports.addStaff = async (req, res, next) => {
  try {
    const {
      full_name,
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number,
      address,
      qualification,
      profession_license,
      employee_number,
      bank_iban,
      salary,
      email,
      username,
      password
    } = req.body;

    // Validate required fields
    if (!full_name?.first || !full_name?.last || !identity_number || !birthday || !gender || !phone_number || !email || !username || !password) {
      return res.status(400).json({ message: '⚠️ Please provide all required fields' });
    }

    // Check if identity number, email, or username already exists
    const existingStaff = await Staff.findOne({
      $or: [
        { identity_number },
        { email },
        { username },
        { employee_number: employee_number || null }
      ]
    });

    if (existingStaff) {
      return res.status(400).json({ message: '⚠️ Staff with this identity number, email, username, or employee number already exists' });
    }

    // Process address - handle both string and object formats
    let processedAddress = address;
    if (typeof address === 'string') {
      // Parse address string like "Ramallah, Palestine"
      const addressParts = address.split(',').map(part => part.trim());
      processedAddress = {
        street: '',
        city: addressParts[0] || '',
        country: addressParts[1] || 'Palestine'
      };
    }

    // Create new staff
    const newStaff = new Staff({
      full_name,
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number,
      address: processedAddress,
      qualification,
      profession_license,
      employee_number: employee_number || `EMP-${Date.now()}`,
      bank_iban,
      salary: salary || 0,
      email,
      username,
      password,
      owner_id: req.user._id,
      date_hired: new Date()
    });

    await newStaff.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null, // Owner action
      action: 'CREATE_STAFF',
      table_name: 'Staff',
      record_id: newStaff._id,
      owner_id: req.user._id
    });

    // Send notification to staff
    await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: newStaff._id,
      receiver_model: 'Staff',
      type: 'system',
      title: 'Welcome to the Team',
      message: `Your account has been created. Username: ${username}. Please login and change your password.`
    });

    res.status(201).json({ 
      message: '✅ Staff member added successfully', 
      staff: await Staff.findById(newStaff._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Staff Member
 * @route   PUT /api/owner/staff/:staffId
 * @access  Private (Owner)
 */
exports.updateStaff = async (req, res, next) => {
  try {
    const staff = await Staff.findOne({ 
      _id: req.params.staffId, 
      owner_id: req.user._id 
    });

    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    const {
      full_name,
      phone_number,
      address,
      qualification,
      profession_license,
      bank_iban,
      salary,
      employee_evaluation,
      email
    } = req.body;

    // Update allowed fields
    if (full_name) staff.full_name = full_name;
    if (phone_number) staff.phone_number = phone_number;
    if (address) {
      // Process address - handle both string and object formats
      if (typeof address === 'string') {
        const addressParts = address.split(',').map(part => part.trim());
        staff.address = {
          street: '',
          city: addressParts[0] || '',
          country: addressParts[1] || 'Palestine'
        };
      } else {
        staff.address = address;
      }
    }
    if (qualification) staff.qualification = qualification;
    if (profession_license) staff.profession_license = profession_license;
    if (bank_iban) staff.bank_iban = bank_iban;
    if (salary !== undefined) staff.salary = salary;
    if (employee_evaluation) staff.employee_evaluation = employee_evaluation;
    if (email) staff.email = email;

    await staff.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_STAFF',
      table_name: 'Staff',
      record_id: staff._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Staff member updated successfully', 
      staff: await Staff.findById(staff._id).select('-password')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Staff Member
 * @route   DELETE /api/owner/staff/:staffId
 * @access  Private (Owner)
 */
exports.deleteStaff = async (req, res, next) => {
  try {
    const staff = await Staff.findOne({ 
      _id: req.params.staffId, 
      owner_id: req.user._id 
    });

    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    // Create audit log before deletion
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_STAFF',
      table_name: 'Staff',
      record_id: staff._id,
      owner_id: req.user._id
    });

    await Staff.findByIdAndDelete(staff._id);

    res.json({ message: '✅ Staff member deleted successfully' });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Doctors
 * @route   GET /api/owner/doctors
 * @access  Private (Owner)
 */
exports.getAllDoctors = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctors = await Doctor.find({ owner_id: req.user._id });
    res.json({ count: doctors.length, doctors });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Doctor
 * @route   GET /api/owner/doctors/:doctorId
 * @access  Private (Owner)
 */
exports.getDoctorById = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctor = await Doctor.findOne({
      _id: req.params.doctorId,
      owner_id: req.user._id
    });

    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    res.json(doctor);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Doctor
 * @route   POST /api/owner/doctors
 * @access  Private (Owner)
 */
exports.addDoctor = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const {
      name,
      phone_number,
      email,
      specialty,
      license_number,
      address
    } = req.body;

    // Validate required fields
    if (!name || !email) {
      return res.status(400).json({ message: '⚠️ Doctor name and email are required' });
    }

    // Check if email already exists
    const existingDoctor = await Doctor.findOne({ email, owner_id: req.user._id });
    if (existingDoctor) {
      return res.status(400).json({ message: '⚠️ Doctor with this email already exists in your lab' });
    }

    const newDoctor = new Doctor({
      name,
      phone_number,
      email,
      specialty,
      license_number,
      address,
      owner_id: req.user._id
    });

    await newDoctor.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_DOCTOR',
      table_name: 'Doctor',
      record_id: newDoctor._id,
      owner_id: req.user._id
    });

    res.status(201).json({ 
      message: '✅ Doctor added successfully', 
      doctor: newDoctor
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Doctor
 * @route   PUT /api/owner/doctors/:doctorId
 * @access  Private (Owner)
 */
exports.updateDoctor = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctor = await Doctor.findOne({ 
      _id: req.params.doctorId, 
      owner_id: req.user._id 
    });

    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    const {
      name,
      phone_number,
      email,
      specialty,
      license_number,
      address
    } = req.body;

    // Update fields
    if (name) doctor.name = name;
    if (phone_number) doctor.phone_number = phone_number;
    if (email) doctor.email = email;
    if (specialty) doctor.specialty = specialty;
    if (license_number) doctor.license_number = license_number;
    if (address) doctor.address = address;

    await doctor.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_DOCTOR',
      table_name: 'Doctor',
      record_id: doctor._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Doctor updated successfully', 
      doctor
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Doctor
 * @route   DELETE /api/owner/doctors/:doctorId
 * @access  Private (Owner)
 */
exports.deleteDoctor = async (req, res, next) => {
  try {
    const Doctor = require('../models/Doctor');
    const doctor = await Doctor.findOne({ 
      _id: req.params.doctorId, 
      owner_id: req.user._id 
    });

    if (!doctor) {
      return res.status(404).json({ message: '❌ Doctor not found' });
    }

    // Check if doctor is referenced in any orders
    const ordersUsingDoctor = await Order.find({ doctor_id: doctor._id });
    if (ordersUsingDoctor.length > 0) {
      return res.status(400).json({ message: '⚠️ Cannot delete doctor. They are referenced in existing orders.' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_DOCTOR',
      table_name: 'Doctor',
      record_id: doctor._id,
      owner_id: req.user._id
    });

    await Doctor.findByIdAndDelete(doctor._id);

    res.json({ message: '✅ Doctor deleted successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== DEVICE MANAGEMENT ====================

/**
 * @desc    Get All Devices
 * @route   GET /api/owner/devices
 * @access  Private (Owner)
 */
exports.getAllDevices = async (req, res, next) => {
  try {
    const devices = await Device.find({ owner_id: req.user._id }).populate('staff_id');
    res.json({ count: devices.length, devices });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Device
 * @route   GET /api/owner/devices/:deviceId
 * @access  Private (Owner)
 */
exports.getDeviceById = async (req, res, next) => {
  try {
    const device = await Device.findOne({
      _id: req.params.deviceId,
      owner_id: req.user._id
    }).populate('staff_id');

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    res.json(device);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Device
 * @route   POST /api/owner/devices
 * @access  Private (Owner)
 */
exports.addDevice = async (req, res, next) => {
  try {
    const {
      name,
      serial_number,
      cleaning_reagent,
      manufacturer,
      status,
      staff_id,
      capacity_of_sample,
      maintenance_schedule
    } = req.body;

    // Validate required fields
    if (!name || !serial_number) {
      return res.status(400).json({ message: '⚠️ Device name and serial number are required' });
    }

    // Check if serial number already exists
    const existingDevice = await Device.findOne({ serial_number });
    if (existingDevice) {
      return res.status(400).json({ message: '⚠️ Device with this serial number already exists' });
    }

    // Verify staff belongs to this owner if staff_id is provided
    if (staff_id) {
      const staff = await Staff.findOne({ _id: staff_id, owner_id: req.user._id });
      if (!staff) {
        return res.status(400).json({ message: '⚠️ Invalid staff member' });
      }
    }

    const newDevice = new Device({
      name,
      serial_number,
      cleaning_reagent,
      manufacturer,
      status: status || 'active',
      staff_id,
      capacity_of_sample,
      maintenance_schedule,
      owner_id: req.user._id
    });

    await newDevice.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_DEVICE',
      table_name: 'Device',
      record_id: newDevice._id,
      owner_id: req.user._id
    });

    res.status(201).json({ 
      message: '✅ Device added successfully', 
      device: await Device.findById(newDevice._id).populate('staff_id')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Device
 * @route   PUT /api/owner/devices/:deviceId
 * @access  Private (Owner)
 */
exports.updateDevice = async (req, res, next) => {
  try {
    const device = await Device.findOne({ 
      _id: req.params.deviceId, 
      owner_id: req.user._id 
    });

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    const {
      name,
      cleaning_reagent,
      manufacturer,
      status,
      staff_id,
      capacity_of_sample,
      maintenance_schedule
    } = req.body;

    // Verify staff belongs to this owner if staff_id is provided
    if (staff_id) {
      const staff = await Staff.findOne({ _id: staff_id, owner_id: req.user._id });
      if (!staff) {
        return res.status(400).json({ message: '⚠️ Invalid staff member' });
      }
    }

    // Update fields
    if (name) device.name = name;
    if (cleaning_reagent) device.cleaning_reagent = cleaning_reagent;
    if (manufacturer) device.manufacturer = manufacturer;
    if (status) device.status = status;
    if (staff_id !== undefined) device.staff_id = staff_id;
    if (capacity_of_sample) device.capacity_of_sample = capacity_of_sample;
    if (maintenance_schedule) device.maintenance_schedule = maintenance_schedule;

    await device.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_DEVICE',
      table_name: 'Device',
      record_id: device._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Device updated successfully', 
      device: await Device.findById(device._id).populate('staff_id')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Assign Staff to Device
 * @route   POST /api/owner/assign-staff-to-device
 * @access  Private (Owner)
 */
exports.assignStaffToDevice = async (req, res, next) => {
  try {
    const { device_id, staff_id } = req.body;

    if (!device_id) {
      return res.status(400).json({ message: '⚠️ Device ID is required' });
    }

    // Find device and verify ownership
    const device = await Device.findOne({ 
      _id: device_id, 
      owner_id: req.user._id 
    });

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    // If staff_id is provided, verify it belongs to this owner
    if (staff_id) {
      const staff = await Staff.findOne({ 
        _id: staff_id, 
        owner_id: req.user._id 
      });

      if (!staff) {
        return res.status(400).json({ 
          message: '⚠️ Staff member not found or does not belong to your lab' 
        });
      }

      // Assign staff to device
      device.staff_id = staff_id;

      // Send notification to staff
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: staff_id,
        receiver_model: 'Staff',
        type: 'system',
        title: 'Device Assigned',
        message: `You have been assigned to operate ${device.name} (${device.serial_number || 'N/A'})`
      });
    } else {
      // Unassign staff (set to null)
      device.staff_id = null;
    }

    await device.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: staff_id ? 'ASSIGN_STAFF_TO_DEVICE' : 'UNASSIGN_STAFF_FROM_DEVICE',
      table_name: 'Device',
      record_id: device._id,
      owner_id: req.user._id
    });

    const populatedDevice = await Device.findById(device._id)
      .populate('staff_id');

    res.json({ 
      success: true,
      message: staff_id 
        ? '✅ Staff assigned to device successfully' 
        : '✅ Staff unassigned from device',
      device: {
        _id: populatedDevice._id,
        name: populatedDevice.name,
        serial_number: populatedDevice.serial_number,
        status: populatedDevice.status,
        assigned_staff: populatedDevice.staff_id ? {
          _id: populatedDevice.staff_id._id,
          name: `${populatedDevice.staff_id.full_name.first} ${populatedDevice.staff_id.full_name.last}`,
          employee_number: populatedDevice.staff_id.employee_number,
          username: populatedDevice.staff_id.username
        } : null
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Device
 * @route   DELETE /api/owner/devices/:deviceId
 * @access  Private (Owner)
 */
exports.deleteDevice = async (req, res, next) => {
  try {
    const device = await Device.findOne({ 
      _id: req.params.deviceId, 
      owner_id: req.user._id 
    });

    if (!device) {
      return res.status(404).json({ message: '❌ Device not found' });
    }

    // Check if device is assigned to any tests
    const testsUsingDevice = await Test.find({ device_id: device._id });
    if (testsUsingDevice.length > 0) {
      return res.status(400).json({ message: '⚠️ Cannot delete device. It is assigned to active tests.' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_DEVICE',
      table_name: 'Device',
      record_id: device._id,
      owner_id: req.user._id
    });

    await Device.findByIdAndDelete(device._id);

    res.json({ message: '✅ Device deleted successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== TEST MANAGEMENT ====================

/**
 * @desc    Get All Tests
 * @route   GET /api/owner/tests
 * @access  Private (Owner)
 */
exports.getAllTests = async (req, res, next) => {
  try {
    const tests = await Test.find({ owner_id: req.user._id }).populate('device_id', 'name serial_number');
    res.json({ count: tests.length, tests });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Test
 * @route   GET /api/owner/tests/:testId
 * @access  Private (Owner)
 */
exports.getTestById = async (req, res, next) => {
  try {
    const test = await Test.findOne({
      _id: req.params.testId,
      owner_id: req.user._id
    }).populate('device_id', 'name serial_number');

    if (!test) {
      return res.status(404).json({ message: '❌ Test not found' });
    }

    res.json(test);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add New Test
 * @route   POST /api/owner/tests
 * @access  Private (Owner)
 */
exports.addTest = async (req, res, next) => {
  try {
    const {
      test_code,
      test_name,
      tube_type,
      is_active,
      device_id,
      method,
      units,
      reference_range,
      price,
      turnaround_time,
      collection_time,
      reagent
    } = req.body;

    // Validate required fields
    if (!test_code || !test_name) {
      return res.status(400).json({ message: '⚠️ Test code and test name are required' });
    }

    // Check if test code already exists for this owner
    const existingTest = await Test.findOne({ test_code, owner_id: req.user._id });
    if (existingTest) {
      return res.status(400).json({ message: '⚠️ Test with this code already exists in your lab' });
    }

    // Verify device belongs to this owner if device_id is provided
    if (device_id) {
      const device = await Device.findOne({ _id: device_id, owner_id: req.user._id });
      if (!device) {
        return res.status(400).json({ message: '⚠️ Invalid device' });
      }
    }

    const newTest = new Test({
      test_code,
      test_name,
      sample_type,
      tube_type,
      is_active: is_active !== undefined ? is_active : true,
      device_id,
      method,
      units,
      reference_range,
      price,
      owner_id: req.user._id,
      turnaround_time,
      collection_time,
      reagent
    });

    await newTest.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_TEST',
      table_name: 'Test',
      record_id: newTest._id,
      owner_id: req.user._id
    });

    res.status(201).json({ 
      message: '✅ Test added successfully', 
      test: await Test.findById(newTest._id).populate('device_id', 'name')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Test
 * @route   PUT /api/owner/tests/:testId
 * @access  Private (Owner)
 */
exports.updateTest = async (req, res, next) => {
  try {
    const test = await Test.findOne({ 
      _id: req.params.testId, 
      owner_id: req.user._id 
    });

    if (!test) {
      return res.status(404).json({ message: '❌ Test not found' });
    }

    const {
      test_name,
      sample_type,
      tube_type,
      is_active,
      device_id,
      method,
      units,
      reference_range,
      price,
      turnaround_time,
      collection_time,
      reagent
    } = req.body;

    // Verify device belongs to this owner if device_id is provided
    if (device_id) {
      const device = await Device.findOne({ _id: device_id, owner_id: req.user._id });
      if (!device) {
        return res.status(400).json({ message: '⚠️ Invalid device' });
      }
    }

    // Update fields
    if (test_name) test.test_name = test_name;
    if (sample_type) test.sample_type = sample_type;
    if (tube_type) test.tube_type = tube_type;
    if (is_active !== undefined) test.is_active = is_active;
    if (device_id !== undefined) test.device_id = device_id;
    if (method) test.method = method;
    if (units) test.units = units;
    if (reference_range) test.reference_range = reference_range;
    if (price !== undefined) test.price = price;
    if (turnaround_time) test.turnaround_time = turnaround_time;
    if (collection_time) test.collection_time = collection_time;
    if (reagent) test.reagent = reagent;

    await test.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_TEST',
      table_name: 'Test',
      record_id: test._id,
      owner_id: req.user._id
    });

    res.json({ 
      message: '✅ Test updated successfully', 
      test: await Test.findById(test._id).populate('device_id', 'name')
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Test
 * @route   DELETE /api/owner/tests/:testId
 * @access  Private (Owner)
 */
exports.deleteTest = async (req, res, next) => {
  try {
    const test = await Test.findOne({ 
      _id: req.params.testId, 
      owner_id: req.user._id 
    });

    if (!test) {
      return res.status(404).json({ message: '❌ Test not found' });
    }

    // Check if test is used in any orders
    const ordersUsingTest = await OrderDetails.find({ test_id: test._id });
    if (ordersUsingTest.length > 0) {
      return res.status(400).json({ message: '⚠️ Cannot delete test. It is used in existing orders.' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_TEST',
      table_name: 'Test',
      record_id: test._id,
      owner_id: req.user._id
    });

    await Test.findByIdAndDelete(test._id);

    res.json({ message: '✅ Test deleted successfully' });
  } catch (err) {
    next(err);
  }
};

// ==================== INVENTORY MANAGEMENT ====================

/**
 * @desc    Get All Inventory Items
 * @route   GET /api/owner/inventory
 * @access  Private (Owner)
 */
exports.getAllInventory = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const items = await Inventory.find({ owner_id: req.user._id });
    
    // Check for low stock and expiring items
    const lowStock = items.filter(item => item.count <= item.critical_level);
    const expiringSoon = items.filter(item => {
      const daysUntilExpiry = Math.ceil((new Date(item.expiration_date) - new Date()) / (1000 * 60 * 60 * 24));
      return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
    });

    res.json({ 
      count: items.length, 
      items,
      alerts: {
        lowStock: lowStock.length,
        expiringSoon: expiringSoon.length
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Inventory Item
 * @route   GET /api/owner/inventory/:itemId
 * @access  Private (Owner)
 */
exports.getInventoryById = async (req, res, next) => {
  try {
    const { Inventory, StockInput, StockOutput } = require('../models/Inventory');
    
    const item = await Inventory.findOne({
      _id: req.params.itemId,
      owner_id: req.user._id
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    // Get transaction history
    const [inputs, outputs] = await Promise.all([
      StockInput.find({ item_id: item._id }).sort({ input_date: -1 }).limit(10),
      StockOutput.find({ item_id: item._id }).sort({ out_date: -1 }).limit(10)
    ]);

    res.json({ 
      item,
      history: {
        recentInputs: inputs,
        recentOutputs: outputs
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add Inventory Item
 * @route   POST /api/owner/inventory
 * @access  Private (Owner)
 */
exports.addInventoryItem = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const {
      name,
      item_code,
      cost,
      expiration_date,
      critical_level,
      count
    } = req.body;

    // Validate required fields
    if (!name || !item_code) {
      return res.status(400).json({ message: '⚠️ Item name and code are required' });
    }

    // Check if item code already exists for this owner
    const existingItem = await Inventory.findOne({ item_code, owner_id: req.user._id });
    if (existingItem) {
      return res.status(400).json({ message: '⚠️ Item with this code already exists' });
    }

    const newItem = new Inventory({
      name,
      item_code,
      cost: cost || 0,
      expiration_date,
      critical_level: critical_level || 10,
      count: count || 0,
      balance: count || 0,
      owner_id: req.user._id
    });

    await newItem.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'CREATE_INVENTORY_ITEM',
      table_name: 'Inventory',
      record_id: newItem._id,
      owner_id: req.user._id
    });

    // Check if stock is low
    if (newItem.count <= newItem.critical_level) {
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: req.user._id,
        receiver_model: 'Owner',
        type: 'system',
        title: 'Low Stock Alert',
        message: `Inventory item "${name}" is at or below critical level (${newItem.count} units).`
      });
    }

    res.status(201).json({ 
      message: '✅ Inventory item added successfully', 
      item: newItem
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Update Inventory Item
 * @route   PUT /api/owner/inventory/:itemId
 * @access  Private (Owner)
 */
exports.updateInventoryItem = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const item = await Inventory.findOne({ 
      _id: req.params.itemId, 
      owner_id: req.user._id 
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    const {
      name,
      cost,
      expiration_date,
      critical_level,
      count
    } = req.body;

    // Update fields
    if (name) item.name = name;
    if (cost !== undefined) item.cost = cost;
    if (expiration_date) item.expiration_date = expiration_date;
    if (critical_level !== undefined) item.critical_level = critical_level;
    if (count !== undefined) {
      item.count = count;
      item.balance = count;
    }

    await item.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'UPDATE_INVENTORY_ITEM',
      table_name: 'Inventory',
      record_id: item._id,
      owner_id: req.user._id
    });

    // Check if stock is low
    if (item.count <= item.critical_level) {
      await Notification.create({
        sender_id: req.user._id,
        sender_model: 'Owner',
        receiver_id: req.user._id,
        receiver_model: 'Owner',
        type: 'system',
        title: 'Low Stock Alert',
        message: `Inventory item "${item.name}" is at or below critical level (${item.count} units).`
      });
    }

    res.json({ 
      message: '✅ Inventory item updated successfully', 
      item
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Delete Inventory Item
 * @route   DELETE /api/owner/inventory/:itemId
 * @access  Private (Owner)
 */
exports.deleteInventoryItem = async (req, res, next) => {
  try {
    const { Inventory } = require('../models/Inventory');
    const item = await Inventory.findOne({ 
      _id: req.params.itemId, 
      owner_id: req.user._id 
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      action: 'DELETE_INVENTORY_ITEM',
      table_name: 'Inventory',
      record_id: item._id,
      owner_id: req.user._id
    });

    await Inventory.findByIdAndDelete(item._id);

    res.json({ message: '✅ Inventory item deleted successfully' });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Add Stock Input to Inventory Item
 * @route   POST /api/owner/inventory/input
 * @access  Private (Owner)
 */
exports.addStockInput = async (req, res, next) => {
  try {
    const { Inventory, StockInput } = require('../models/Inventory');
    const {
      item_id,
      quantity,
      supplier,
      batch_number,
      expiration_date,
      cost_per_unit,
      notes
    } = req.body;

    // Validate required fields
    if (!item_id || !quantity) {
      return res.status(400).json({ message: '⚠️ Item ID and quantity are required' });
    }

    // Find the inventory item
    const item = await Inventory.findOne({ 
      _id: item_id, 
      owner_id: req.user._id 
    });

    if (!item) {
      return res.status(404).json({ message: '❌ Inventory item not found' });
    }

    // Create stock input record
    const stockInput = new StockInput({
      item_id,
      quantity: parseInt(quantity),
      supplier,
      batch_number,
      expiration_date,
      cost_per_unit: cost_per_unit || 0,
      notes,
      input_date: new Date()
    });

    await stockInput.save();

    // Update inventory count
    item.count += parseInt(quantity);
    item.balance = item.count;
    if (expiration_date) {
      item.expiration_date = expiration_date;
    }
    await item.save();

    // Create audit log
    await AuditLog.create({
      staff_id: null,
      username: req.user.username,
      action: 'STOCK_INPUT',
      table_name: 'Inventory',
      record_id: item._id,
      owner_id: req.user._id,
      message: `Added ${quantity} units to ${item.name}`
    });

    // Check if stock is no longer low
    if (item.count > item.critical_level) {
      // Could send notification that stock is back to normal
    }

    res.status(201).json({ 
      message: '✅ Stock input added successfully', 
      item,
      stockInput
    });
  } catch (err) {
    next(err);
  }
};

// ==================== DASHBOARD & ANALYTICS ====================

/**
 * @desc    Get Dashboard Statistics
 * @route   GET /api/owner/dashboard
 * @access  Private (Owner)
 */
exports.getDashboard = async (req, res, next) => {
  try {
    // Get counts
    const [staffCount, deviceCount, testCount] = await Promise.all([
      Staff.countDocuments({ owner_id: req.user._id }),
      Device.countDocuments({ owner_id: req.user._id }),
      Test.countDocuments({ owner_id: req.user._id })
    ]);
    
    // Get unique patients who have orders with this lab
    const patientOrders = await Order.find({ owner_id: req.user._id }).distinct('patient_id');
    const patientCount = patientOrders.filter(id => id != null).length;
    
    const { Inventory } = require('../models/Inventory');
    const inventoryCount = await Inventory.countDocuments({ owner_id: req.user._id });

    // Get order statistics
    const totalOrders = await Order.countDocuments({ owner_id: req.user._id });
    const processingOrders = await Order.countDocuments({ owner_id: req.user._id, status: 'processing' });
    const completedOrders = await Order.countDocuments({ owner_id: req.user._id, status: 'completed' });

    // Get order details statistics
    const pendingTests = await OrderDetails.countDocuments({ status: 'pending' });
    const inProgressTests = await OrderDetails.countDocuments({ status: 'in_progress' });
    const completedTests = await OrderDetails.countDocuments({ status: 'completed' });

    // Get low stock items
    const inventoryItems = await Inventory.find({ owner_id: req.user._id });
    const lowStockItems = inventoryItems.filter(item => item.count <= item.critical_level);
    const expiringItems = inventoryItems.filter(item => {
      const daysUntilExpiry = Math.ceil((new Date(item.expiration_date) - new Date()) / (1000 * 60 * 60 * 24));
      return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
    });

    // Get revenue statistics (current month)
    const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const invoices = await Invoice.find({ 
      owner_id: req.user._id,
      invoice_date: { $gte: startOfMonth }
    });
    
    const monthlyRevenue = invoices.reduce((sum, inv) => sum + (inv.total_amount || 0), 0);
    const paidInvoices = invoices.filter(inv => inv.payment_status === 'paid').length;
    const pendingInvoices = invoices.filter(inv => inv.payment_status === 'pending').length;

    // Get recent notifications
    const notifications = await Notification.find({ 
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    })
    .sort({ createdAt: -1 })
    .limit(5);

    const unreadNotifications = await Notification.countDocuments({ 
      receiver_id: req.user._id,
      receiver_model: 'Owner',
      is_read: false
    });

    res.json({
      resources: {
        staff: staffCount,
        devices: deviceCount,
        tests: testCount,
        patients: patientCount,
        inventory: inventoryCount
      },
      orders: {
        total: totalOrders,
        processing: processingOrders,
        completed: completedOrders
      },
      testDetails: {
        pending: pendingTests,
        inProgress: inProgressTests,
        completed: completedTests
      },
      inventory: {
        lowStock: lowStockItems.length,
        expiring: expiringItems.length,
        lowStockItems: lowStockItems.slice(0, 5),
        expiringItems: expiringItems.slice(0, 5)
      },
      financials: {
        monthlyRevenue,
        paidInvoices,
        pendingInvoices
      },
      notifications: {
        unread: unreadNotifications,
        recent: notifications
      }
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Performance Reports
 * @route   GET /api/owner/reports
 * @access  Private (Owner)
 */
/**
 * @desc    Get All Orders
 * @route   GET /api/owner/orders
 * @access  Private (Owner)
 */
exports.getAllOrders = async (req, res, next) => {
  try {
    const { status, startDate, endDate, page = 1, limit = 50 } = req.query;

    const query = { owner_id: req.user._id };
    
    // Filter by status if provided
    if (status) {
      query.status = status;
    }

    // Filter by date range if provided
    if (startDate || endDate) {
      query.order_date = {};
      if (startDate) query.order_date.$gte = new Date(startDate);
      if (endDate) query.order_date.$lte = new Date(endDate);
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [orders, total] = await Promise.all([
      Order.find(query)
        .populate('patient_id', 'full_name patient_id phone_number email')
        .populate('doctor_id', 'name')
        .sort({ order_date: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Order.countDocuments(query)
    ]);

    // Filter out orders where patient_id doesn't exist (deleted/invalid reference)
    // and where patient is not fully registered
    const validOrders = orders.filter(order => {
      // Include only if patient_id exists and populated successfully
      // OR if temp_patient_info exists (for orders awaiting patient registration)
      return order.patient_id || order.temp_patient_info?.full_name;
    });

    // Enrich orders with test details
    const enrichedOrders = await Promise.all(validOrders.map(async (order) => {
      const orderDetails = await OrderDetails.find({ order_id: order._id })
        .populate('test_id', 'test_name test_code price')
        .populate('staff_id', 'full_name employee_number')
        .select('test_id staff_id status');
      
      const orderObj = order.toObject();
      
      // Add flattened patient and doctor names for easier access
      // Try patient_id first, then fall back to temp_patient_info
      if (order.patient_id?.full_name) {
        orderObj.patient_name = `${order.patient_id.full_name.first || ''} ${order.patient_id.full_name.middle || ''} ${order.patient_id.full_name.last || ''}`.trim();
      } else if (order.temp_patient_info?.full_name) {
        orderObj.patient_name = `${order.temp_patient_info.full_name.first || ''} ${order.temp_patient_info.full_name.middle || ''} ${order.temp_patient_info.full_name.last || ''}`.trim();
      } else {
        orderObj.patient_name = 'Unknown Patient';
      }
      
      orderObj.doctor_name = order.doctor_id?.name || '-';
      
      // Get results for all order details
      const detailIds = orderDetails.map(d => d._id);
      const Result = require('../models/Result');
      const results = await Result.find({ detail_id: { $in: detailIds } });
      
      // Add test details with staff assignments and results
      orderObj.order_details = orderDetails.map(detail => {
        const result = results.find(r => r.detail_id.toString() === detail._id.toString());
        return {
          test_name: detail.test_id?.test_name || 'Unknown Test',
          test_code: detail.test_id?.test_code,
          price: detail.test_id?.price,
          status: detail.status,
          staff_name: detail.staff_id?.full_name 
            ? `${detail.staff_id.full_name.first || ''} ${detail.staff_id.full_name.last || ''}`.trim()
            : null,
          staff_employee_number: detail.staff_id?.employee_number,
          has_result: !!result,
          result_value: result?.result_value || null,
          result_units: result?.units || null,
          result_reference_range: result?.reference_range || null,
          result_remarks: result?.remarks || null
        };
      });
      
      orderObj.test_count = orderDetails.length;
      
      return orderObj;
    }));

    res.json({
      total: enrichedOrders.length,
      page: parseInt(page),
      totalPages: Math.ceil(enrichedOrders.length / parseInt(limit)),
      orders: enrichedOrders
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Single Order
 * @route   GET /api/owner/orders/:orderId
 * @access  Private (Owner)
 */
exports.getOrderById = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      _id: req.params.orderId,
      owner_id: req.user._id
    })
      .populate('patient_id', 'full_name patient_id phone_number email identity_number')
      .populate('doctor_id', 'name phone_number email');

    if (!order) {
      return res.status(404).json({ message: '❌ Order not found' });
    }

    // Get order details (tests)
    const orderDetails = await OrderDetails.find({ order_id: order._id })
      .populate('test_id', 'test_name test_code price')
      .populate('staff_id', 'full_name employee_number')
      .populate('result_id');

    // Get invoice if exists
    const invoice = await Invoice.findOne({ order_id: order._id });

    res.json({
      order,
      tests: orderDetails,
      invoice
    });
  } catch (err) {
    next(err);
  }
};

exports.getReports = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    let start = startDate ? new Date(startDate) : new Date(new Date().setMonth(new Date().getMonth() - 1));
    let end = endDate ? new Date(endDate) : new Date();

    const query = { 
      owner_id: req.user._id,
      order_date: { $gte: start, $lte: end }
    };

    // Get orders in date range
    const orders = await Order.find(query).populate('patient_id', 'full_name patient_id');

    // Get invoices in date range
    const invoices = await Invoice.find({
      owner_id: req.user._id,
      invoice_date: { $gte: start, $lte: end }
    });

    const totalRevenue = invoices.reduce((sum, inv) => sum + (inv.total_amount || 0), 0);
    const paidRevenue = invoices
      .filter(inv => inv.payment_status === 'paid')
      .reduce((sum, inv) => sum + (inv.total_amount || 0), 0);

    // Get staff performance
    const orderDetails = await OrderDetails.find({
      status: 'completed'
    }).populate({
      path: 'order_id',
      match: { owner_id: req.user._id, order_date: { $gte: start, $lte: end } }
    });

    const staffPerformance = {};
    for (const detail of orderDetails) {
      if (detail.order_id && detail.staff_id) {
        const staffId = detail.staff_id.toString();
        if (!staffPerformance[staffId]) {
          staffPerformance[staffId] = { count: 0, staff_id: staffId };
        }
        staffPerformance[staffId].count++;
      }
    }

    // Populate staff names
    const staffIds = Object.keys(staffPerformance);
    const staffMembers = await Staff.find({ _id: { $in: staffIds } }).select('full_name employee_number');
    staffMembers.forEach(staff => {
      if (staffPerformance[staff._id.toString()]) {
        staffPerformance[staff._id.toString()].name = `${staff.full_name.first} ${staff.full_name.last}`;
        staffPerformance[staff._id.toString()].employee_number = staff.employee_number;
      }
    });

    // Get expenses
    const staff = await Staff.find({ owner_id: req.user._id });
    const totalSalaries = staff.reduce((sum, s) => sum + (s.salary || 0), 0);
    
    // Calculate subscription fee
    const subscriptionFee = await calculateTieredFee(req.user._id);
    const subscriptions = subscriptionFee.total;
    
    // Inventory expenses - placeholder for now (set to 0)
    const inventory = 0;

    res.json({
      period: { start, end },
      orders: {
        total: orders.length,
        completed: orders.filter(o => o.status === 'completed').length,
        processing: orders.filter(o => o.status === 'processing').length
      },
      revenue: {
        total: totalRevenue,
        paid: paidRevenue,
        pending: totalRevenue - paidRevenue
      },
      expenses: {
        salaries: totalSalaries,
        subscriptions: subscriptions,
        inventory: inventory
      },
      staffPerformance: Object.values(staffPerformance).sort((a, b) => b.count - a.count)
    });
  } catch (err) {
    next(err);
  }
};

// ==================== NOTIFICATIONS ====================

/**
 * @desc    Get All Notifications
 * @route   GET /api/owner/notifications
 * @access  Private (Owner)
 */
exports.getNotifications = async (req, res, next) => {
  try {
    const { unreadOnly } = req.query;
    
    const query = {
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    };

    if (unreadOnly === 'true') {
      query.is_read = false;
    }

    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .populate('sender_id', 'name username');

    res.json({ count: notifications.length, notifications });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Mark Notification as Read
 * @route   PUT /api/owner/notifications/:notificationId/read
 * @access  Private (Owner)
 */
exports.markNotificationAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    });

    if (!notification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    notification.is_read = true;
    await notification.save();

    res.json({ message: '✅ Notification marked as read' });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Send Notification to Staff
 * @route   POST /api/owner/notifications/send
 * @access  Private (Owner)
 */
exports.sendNotificationToStaff = async (req, res, next) => {
  try {
    const { staff_id, title, message, type } = req.body;

    if (!staff_id || !title || !message) {
      return res.status(400).json({ message: '⚠️ Staff ID, title, and message are required' });
    }

    // Verify staff belongs to this owner
    const staff = await Staff.findOne({ _id: staff_id, owner_id: req.user._id });
    if (!staff) {
      return res.status(404).json({ message: '❌ Staff member not found' });
    }

    const notification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: staff_id,
      receiver_model: 'Staff',
      type: type || 'system',
      title,
      message
    });

    res.status(201).json({ 
      message: '✅ Notification sent successfully', 
      notification 
    });
  } catch (err) {
    next(err);
  }
};

// ==================== COMMUNICATION WITH ADMIN ====================

/**
 * @desc    Request Subscription Renewal
 * @route   POST /api/owner/request-renewal
 * @access  Private (Owner)
 */
exports.requestSubscriptionRenewal = async (req, res, next) => {
  try {
    const { renewal_duration, message } = req.body;

    const owner = await LabOwner.findById(req.user._id);
    
    // Calculate days until expiration
    const today = new Date();
    const endDate = new Date(owner.subscription_end);
    const daysRemaining = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));

    // Get the admin who approved this owner
    const Admin = require('../models/Admin');
    const admin = await Admin.findById(owner.admin_id);

    if (!admin) {
      return res.status(404).json({ message: '❌ Admin not found' });
    }

    const renewalMessage = message || 
      `I would like to renew my lab subscription for ${renewal_duration || 'another year'}. ` +
      `Current subscription ${daysRemaining < 0 ? `expired ${Math.abs(daysRemaining)} days ago` : `expires in ${daysRemaining} days`}.`;

    const notification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'subscription',
      title: '🔄 Subscription Renewal Request',
      message: `From Lab Owner (${owner.name.first} ${owner.name.last}): ${renewalMessage}`
    });

    res.status(201).json({ 
      message: '✅ Subscription renewal request sent to admin successfully',
      currentSubscriptionEnd: owner.subscription_end,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
      notification 
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Send Message to Admin
 * @route   POST /api/owner/contact-admin
 * @access  Private (Owner)
 */
exports.contactAdmin = async (req, res, next) => {
  try {
    const { title, message } = req.body;

    if (!title || !message) {
      return res.status(400).json({ message: '⚠️ Title and message are required' });
    }

    const owner = await LabOwner.findById(req.user._id);
    
    // Get the admin who approved this owner
    const Admin = require('../models/Admin');
    const admin = await Admin.findById(owner.admin_id);

    if (!admin) {
      return res.status(404).json({ message: '❌ Admin not found' });
    }

    const notification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      title,
      message: `From Lab Owner (${owner.name.first} ${owner.name.last}): ${message}`
    });

    res.status(201).json({ 
      message: '✅ Message sent to admin successfully', 
      notification 
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Reply to Notification
 * @route   POST /api/owner/notifications/:notificationId/reply
 * @access  Private (Owner)
 */
exports.replyToNotification = async (req, res, next) => {
  try {
    const { notificationId } = req.params;
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({ message: '⚠️ Reply message is required' });
    }

    // Get the original notification
    const originalNotification = await Notification.findOne({
      _id: notificationId,
      receiver_id: req.user._id,
      receiver_model: 'Owner'
    });

    if (!originalNotification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    // Determine conversation_id (use parent's conversation_id or original notification's _id)
    const conversationId = originalNotification.conversation_id || originalNotification._id;

    // Create reply notification
    const replyNotification = await Notification.create({
      sender_id: req.user._id,
      sender_model: 'Owner',
      receiver_id: originalNotification.sender_id,
      receiver_model: originalNotification.sender_model,
      type: 'message',
      title: `Re: ${originalNotification.title}`,
      message,
      parent_id: notificationId,
      conversation_id: conversationId,
      is_reply: true
    });

    // Update original notification's conversation_id if it doesn't have one
    if (!originalNotification.conversation_id) {
      originalNotification.conversation_id = originalNotification._id;
      await originalNotification.save();
    }

    res.status(201).json({
      message: '✅ Reply sent successfully',
      notification: replyNotification
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Conversation Thread
 * @route   GET /api/owner/notifications/:notificationId/conversation
 * @access  Private (Owner)
 */
exports.getConversationThread = async (req, res, next) => {
  try {
    const { notificationId } = req.params;

    // Get the notification to find its conversation_id
    const notification = await Notification.findById(notificationId);

    if (!notification) {
      return res.status(404).json({ message: '❌ Notification not found' });
    }

    // Verify owner has access to this conversation
    if (notification.receiver_id.toString() !== req.user._id.toString() &&
        notification.sender_id?.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: '❌ Access denied' });
    }

    const conversationId = notification.conversation_id || notification._id;

    // Get all messages in the conversation
    const messages = await Notification.find({
      $or: [
        { _id: conversationId },
        { conversation_id: conversationId }
      ]
    })
    .sort({ createdAt: 1 });

    res.json({
      conversation_id: conversationId,
      message_count: messages.length,
      messages
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get All Conversations (grouped notifications)
 * @route   GET /api/owner/conversations
 * @access  Private (Owner)
 */
exports.getConversations = async (req, res, next) => {
  try {
    // Get all notifications where owner is sender or receiver
    const allNotifications = await Notification.find({
      $or: [
        { receiver_id: req.user._id, receiver_model: 'Owner' },
        { sender_id: req.user._id, sender_model: 'Owner' }
      ]
    })
    .sort({ createdAt: -1 });

    // Group by conversation_id
    const conversationMap = new Map();

    for (const notification of allNotifications) {
      const convId = (notification.conversation_id || notification._id).toString();
      
      if (!conversationMap.has(convId)) {
        conversationMap.set(convId, {
          conversation_id: convId,
          messages: [],
          last_message: notification,
          unread_count: 0,
          participant: notification.sender_id?.toString() === req.user._id.toString()
            ? notification.receiver_id
            : notification.sender_id
        });
      }

      const conversation = conversationMap.get(convId);
      conversation.messages.push(notification);
      
      // Update last message if this one is newer
      if (new Date(notification.createdAt) > new Date(conversation.last_message.createdAt)) {
        conversation.last_message = notification;
      }

      // Count unread messages
      if (!notification.is_read && notification.receiver_id?.toString() === req.user._id.toString()) {
        conversation.unread_count++;
      }
    }

    // Convert map to array and sort by last message time
    const conversations = Array.from(conversationMap.values())
      .sort((a, b) => new Date(b.last_message.createdAt) - new Date(a.last_message.createdAt));

    res.json({
      total: conversations.length,
      conversations
    });
  } catch (err) {
    next(err);
  }
};

// ==================== AUDIT LOGS ====================

/**
 * @desc    Get Audit Logs
 * @route   GET /api/owner/audit-logs
 * @access  Private (Owner)
 */
exports.getAuditLogs = async (req, res, next) => {
  try {
    const { startDate, endDate, action, limit = 50 } = req.query;

    const query = { owner_id: req.user._id };

    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    if (action) {
      query.action = action;
    }

    const logs = await AuditLog.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .populate('staff_id', 'full_name employee_number');

    res.json({ count: logs.length, logs });
  } catch (err) {
    next(err);
  }
};

// ==================== PATIENTS VIEW (Read-Only) ====================

/**
 * @desc    Get All Patients (who had tests in this lab)
 * @route   GET /api/owner/patients
 * @access  Private (Owner)
 */
exports.getAllPatients = async (req, res, next) => {
  try {
    // Get all orders for this lab
    const orders = await Order.find({ owner_id: req.user._id })
      .populate('patient_id', 'full_name identity_number patient_id phone_number email')
      .select('patient_id');

    // Extract unique patient IDs
    const patientIds = [...new Set(orders.map(o => o.patient_id?._id?.toString()).filter(Boolean))];
    
    const patients = await Patient.find({ _id: { $in: patientIds } }).select('-password');

    res.json({ count: patients.length, patients });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Get Patient Details
 * @route   GET /api/owner/patients/:patientId
 * @access  Private (Owner)
 */
exports.getPatientById = async (req, res, next) => {
  try {
    const patient = await Patient.findById(req.params.patientId).select('-password');
    
    if (!patient) {
      return res.status(404).json({ message: '❌ Patient not found' });
    }

    // Verify patient has orders in this lab
    const hasOrders = await Order.findOne({ 
      patient_id: patient._id, 
      owner_id: req.user._id 
    });

    if (!hasOrders) {
      return res.status(403).json({ message: '⚠️ No records found for this patient in your lab' });
    }

    // Get patient's order history in this lab
    const orders = await Order.find({ 
      patient_id: patient._id, 
      owner_id: req.user._id 
    }).populate('requested_by', 'full_name');

    res.json({ patient, orderHistory: orders });
  } catch (err) {
    next(err);
  }
};

// ==================== FEEDBACK METHODS ====================

/**
 * @desc    Provide Feedback
 * @route   POST /api/owner/feedback
 * @access  Private (Owner)
 */
exports.provideFeedback = async (req, res, next) => {
  try {
    const owner_id = req.user._id;
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

    // Validate target exists and owner has access (skip for system feedback)
    let targetExists = target_type === 'system';
    let targetOwnerId = null;

    if (target_type !== 'system') {
      switch (target_type) {
        case 'lab':
          const lab = await LabOwner.findById(target_id);
          if (lab) {
            targetExists = true;
            targetOwnerId = lab._id;
          }
          break;
        case 'test':
          const test = await Test.findById(target_id);
          if (test && test.owner_id.toString() === owner_id.toString()) {
            targetExists = true;
            targetOwnerId = test.owner_id;
          }
          break;
        case 'order':
          const order = await Order.findOne({
            _id: target_id,
            owner_id: owner_id
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
      user_id: owner_id,
      user_model: 'Owner',
      target_type,
      target_id: target_type === 'system' ? null : target_id,
      rating,
      message: message || '',
      is_anonymous: is_anonymous || false
    });

    await feedback.save();

    // Send notification to lab owner (skip for system feedback or self-feedback)
    if (targetOwnerId && targetOwnerId.toString() !== owner_id.toString()) {
      await Notification.create({
        sender_id: owner_id,
        sender_model: 'Owner',
        receiver_id: targetOwnerId,
        receiver_model: 'Owner',
        type: 'feedback',
        title: '⭐ New Feedback Received',
        message: `Lab owner provided ${rating}-star feedback on your ${target_type}`
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
    next(err);
  }
};

/**
 * @desc    Get My Feedback History
 * @route   GET /api/owner/feedback
 * @access  Private (Owner)
 */
exports.getMyFeedback = async (req, res, next) => {
  try {
    const owner_id = req.user._id;
    const { page = 1, limit = 10, target_type } = req.query;

    const query = {
      user_id: owner_id,
      user_model: 'Owner'
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
    next(err);
  }
};

module.exports = exports;
