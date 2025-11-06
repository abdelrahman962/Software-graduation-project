const Staff = require("../models/Staff");
const Patient = require("../models/Patient");
const Test = require("../models/Test");
const OrderDetails = require("../models/OrderDetails");
const Result = require("../models/Result");
const { Inventory } = require("../models/Inventory");
const Device = require("../models/Device");
const Notification = require("../models/Notification");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const sendEmail = require("../utils/sendEmail");
const logAction = require("../utils/logAction");


// ✅ Staff Login (with login history + logging)
exports.loginStaff = async (req, res) => {
  try {
    const { username, password } = req.body;
    const staff = await Staff.findOne({ username });

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
    await logAction(staff._id, `Staff ${staff.username} logged in at ${staff.last_login}`);

    const token = jwt.sign({ id: staff._id }, process.env.JWT_SECRET, { expiresIn: "7d" });
    res.json({ message: "Login successful", token, staff });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


// ✅ Register New Patient
exports.registerPatient = async (req, res) => {
  try {
    const { name, email, phone_number } = req.body;

    const username = email.split("@")[0];
    const tempPassword = Math.random().toString(36).slice(-8);

    const patient = await Patient.create({
      ...req.body,
      username,
      password: tempPassword
    });

    await sendEmail(
      email,
      "Patient Account Created",
      `Your lab account is created.\nUsername: ${username}\nPassword: ${tempPassword}`
    );

    res.status(201).json({ message: "Patient registered successfully", patient });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};


exports.uploadResult = async (req, res) => {
  try {
    const { detail_id, result_value, remarks, staff_id } = req.body;

    // 1️⃣ Load order detail with related test + order
    const detail = await OrderDetails.findById(detail_id)
      .populate("test_id")
      .populate({
        path: "order_id",
        populate: [{ path: "patient_id" }, { path: "doctor_id" }, { path: "owner_id" }]
      });

    if (!detail) return res.status(404).json({ message: "Order detail not found" });

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
      result_value,
      units: test.units,
      reference_range: test.reference_range,
      remarks
    });

    // 4️⃣ If urgent → mark order as urgent + send notifications
    if (isUrgent) {
      order.remarks = "urgent";
      await order.save();

      const notifications = [];

      // 🔔 To the Doctor (if exists)
      if (order.doctor_id) {
        notifications.push({
          sender_id: staff_id,
          sender_model: "Staff",
          receiver_id: order.doctor_id._id,
          receiver_model: "Doctor",
          type: "test_result",
          title: "Urgent Test Result",
          message: `Test ${test.test_name} result for patient ${order.patient_id?.name || ""} is outside normal range.`,
          related_id: result._id
        });
      }

      // 🔔 To the Patient
      if (order.patient_id) {
        notifications.push({
          sender_id: staff_id,
          sender_model: "Staff",
          receiver_id: order.patient_id._id,
          receiver_model: "Patient",
          type: "test_result",
          title: "Urgent Test Result",
          message: `Your test result for ${test.test_name} is outside the normal range. Please contact your doctor.`,
          related_id: result._id
        });
      }

      // ✅ Save notifications
      if (notifications.length > 0) {
        await Notification.insertMany(notifications);
      }
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




exports.reportIssue = async (req, res) => {
  try {
    const { staff_id, issue_type, related_id, message } = req.body;

    if (!["device", "reagent"].includes(issue_type)) {
      return res.status(400).json({ message: "Invalid issue type. Must be 'device' or 'reagent'." });
    }

    // Fetch more info for context
    let title = "Issue Reported";
    let description = "";

    if (issue_type === "device") {
      const device = await Device.findById(related_id);
      if (!device) return res.status(404).json({ message: "Device not found" });
      description = `Device Issue: ${device.name} (SN: ${device.serial_number})`;
    } else if (issue_type === "reagent") {
      const reagent = await Inventory.findById(related_id);
      if (!reagent) return res.status(404).json({ message: "Reagent not found" });
      description = `Reagent Issue: ${reagent.name}, Batch Code: ${reagent.item_code}`;
    }

    // ✅ Create notification for lab owner
    await Notification.create({
      sender_id: staff_id,
      sender_model: "Staff",
      receiver_model: "LabOwner",
      type: "maintenance",
      title,
      message: `${description}\nDetails: ${message}`,
      related_id,
      created_at: new Date()
    });

    // Optional: add audit log
    // await AuditLog.create({
    //   staff_id,
    //   action: `Reported ${issue_type} issue`,
    //   table_name: issue_type === "device" ? "Device" : "Inventory",
    //   record_id: related_id,
    //   owner_id: <owner_id_from_device_or_staff>
    // });

    res.status(201).json({ message: `${issue_type} issue reported successfully` });
  } catch (err) {
    console.error("Error reporting issue:", err);
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


// ✅ Update Sample Status
exports.updateSampleStatus = async (req, res) => {
  try {
    const { detail_id, status } = req.body;

    const validStatuses = ["Pending", "Collected", "In Progress", "Completed"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ message: "Invalid status value" });
    }

    const detail = await OrderDetails.findById(detail_id);
    if (!detail) return res.status(404).json({ message: "Order detail not found" });

    detail.status = status;
    if (status === "Collected") detail.sample_collected = true;

    await detail.save();
    await logAction(detail.staff_id, `Updated sample status to ${status} for OrderDetail ${detail_id}`);

    res.json({ message: "Sample status updated successfully", detail });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};



// ✅ Get Staff Assigned Devices
exports.getStaffDevices = async (req, res) => {
  try {
    const { staff_id } = req.params;
    const devices = await Device.find({ assigned_to: staff_id });
    res.json(devices);
  } catch (err) {
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
