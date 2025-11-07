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
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// ==================== AUTHENTICATION ====================

/**
 * @desc    Lab Owner Login
 * @route   POST /api/owner/login
 * @access  Public
 */


// ==================== LAB OWNER LOGIN ====================
exports.login = async (req, res, next) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ message: '⚠️ Username and password are required' });

    const owner = await LabOwner.findOne({ username });
    if (!owner) return res.status(401).json({ message: '❌ Invalid credentials' });

    if (owner.status !== 'approved') return res.status(403).json({ message: '⚠️ Account is not approved yet.' });
    if (!owner.is_active) return res.status(403).json({ message: '⚠️ Account is inactive. Please contact support.' });
    if (owner.subscription_end && new Date() > new Date(owner.subscription_end)) return res.status(403).json({ message: '⚠️ Your subscription has expired. Please renew to continue.' });

    const isMatch = await owner.comparePassword(password);
    if (!isMatch) return res.status(401).json({ message: '❌ Invalid credentials' });

    const token = jwt.sign(
      { _id: owner._id, owner_id: owner.owner_id, role: 'owner', username: owner.username },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: '✅ Login successful',
      token,
      owner: {
        _id: owner._id,
        owner_id: owner.owner_id,
        name: owner.name,
        email: owner.email,
        username: owner.username,
        subscription_end: owner.subscription_end
      }
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
    const { first_name, middle_name, last_name, identity_number, birthday, gender, social_status, phone, address, qualification, profession_license, bank_iban, email, username, password } = req.body;

    if (!first_name || !last_name || !identity_number || !email || !username || !password)
      return res.status(400).json({ message: '⚠️ Missing required fields' });

    const existingOwner = await LabOwner.findOne({ $or: [{ email }, { username }, { identity_number }] });
    if (existingOwner) return res.status(400).json({ message: '⚠️ Lab Owner with provided email, username, or ID already exists' });

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
      is_active: false
    });

    const admins = await Admin.find({});
    const notifications = admins.map(admin => ({
      sender_id: newRequest._id,
      sender_model: 'Owner',
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      title: 'New Lab Owner Request',
      message: `Lab Owner ${first_name} ${last_name} has requested access to the system.`
    }));
    await Notification.insertMany(notifications);

    res.status(201).json({
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

    res.json(owner);
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
    if (address) owner.address = address;
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
      return res.status(400).json({ message: '⚠️ Current password and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: '⚠️ New password must be at least 6 characters' });
    }

    const owner = await LabOwner.findById(req.user._id);
    if (!owner) {
      return res.status(404).json({ message: '❌ Owner not found' });
    }

    // Verify current password
    const isMatch = await owner.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ message: '❌ Current password is incorrect' });
    }

    // Update password
    owner.password = newPassword;
    await owner.save();

    res.json({ message: '✅ Password changed successfully' });
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

    // Create new staff
    const newStaff = new Staff({
      full_name,
      identity_number,
      birthday,
      gender,
      social_status,
      phone_number,
      address,
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
    if (address) staff.address = address;
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

// ==================== DEVICE MANAGEMENT ====================

/**
 * @desc    Get All Devices
 * @route   GET /api/owner/devices
 * @access  Private (Owner)
 */
exports.getAllDevices = async (req, res, next) => {
  try {
    const devices = await Device.find({ owner_id: req.user._id }).populate('staff_id', 'full_name employee_number');
    res.json({ count: devices.length, devices });
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
      device: await Device.findById(newDevice._id).populate('staff_id', 'full_name')
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
      device: await Device.findById(device._id).populate('staff_id', 'full_name')
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
 * @desc    Add New Test
 * @route   POST /api/owner/tests
 * @access  Private (Owner)
 */
exports.addTest = async (req, res, next) => {
  try {
    const {
      test_code,
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

// ==================== DASHBOARD & ANALYTICS ====================

/**
 * @desc    Get Dashboard Statistics
 * @route   GET /api/owner/dashboard
 * @access  Private (Owner)
 */
exports.getDashboard = async (req, res, next) => {
  try {
    // Get counts
    const staffCount = await Staff.countDocuments({ owner_id: req.user._id });
    const deviceCount = await Device.countDocuments({ owner_id: req.user._id });
    const testCount = await Test.countDocuments({ owner_id: req.user._id });
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
    .sort({ created_at: -1 })
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
      .sort({ created_at: -1 })
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


module.exports = exports;
