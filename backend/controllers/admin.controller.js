const { v4: uuidv4 } = require("uuid");
const bcrypt = require("bcryptjs");
const User = require("../models/User");
const Tenant = require("../models/Tenant");
const Firmware = require("../models/Firmware");
const Device = require("../models/Device");
const DeviceMember = require("../models/DeviceMember");
const FeedLog = require("../models/FeedLog");
const AdminLog = require("../models/AdminLog");
const PairingToken = require("../models/PairingToken");

const logAction = (admin_uid, action, target_type, target_id, details, ip) =>
  AdminLog.create({ admin_uid, action, target_type, target_id, details, ip_address: ip });

// GET /api/admin/stats
const getStats = async (req, res) => {
  try {
    const today = new Date(); today.setHours(0,0,0,0);
    const tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1);

    const [totalUsers, totalDevices, onlineDevices, todayFeeds, failedFeeds] = await Promise.all([
      User.countDocuments({ role: "user" }),
      Device.countDocuments(),
      Device.countDocuments({ status: "online" }),
      FeedLog.countDocuments({ triggered_at: { $gte: today, $lt: tomorrow } }),
      FeedLog.countDocuments({ status: "failed", triggered_at: { $gte: today, $lt: tomorrow } }),
    ]);

    const recentActivity = await FeedLog.find().sort({ triggered_at: -1 }).limit(10);

    res.json({ success: true, stats: { totalUsers, totalDevices, onlineDevices, offlineDevices: totalDevices - onlineDevices, todayFeeds, failedFeeds, recentActivity } });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch stats" });
  }
};

// GET /api/admin/users
const listUsers = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";
    const filter = search ? { $or: [{ name: { $regex: search, $options: "i" } }, { email: { $regex: search, $options: "i" } }] } : {};
    const users = await User.find(filter).select("-password_hash").sort({ created_at: -1 }).skip((page-1)*limit).limit(limit);
    const total = await User.countDocuments(filter);
    res.json({ success: true, users, total, page });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch users" });
  }
};

// PUT /api/admin/users/:uid
const updateUser = async (req, res) => {
  try {
    const { role, is_active } = req.body;
    const updates = { updated_at: new Date() };
    if (role) updates.role = role;
    if (is_active !== undefined) updates.is_active = is_active;
    const user = await User.findOneAndUpdate({ uid: req.params.uid }, updates, { new: true, select: "-password_hash" });
    await logAction(req.user.uid, "update_user", "user", req.params.uid, req.body, req.ip);
    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, message: "User update failed" });
  }
};

// DELETE /api/admin/users/:uid
const deleteUser = async (req, res) => {
  try {
    await User.deleteOne({ uid: req.params.uid });
    await DeviceMember.deleteMany({ user_uid: req.params.uid });
    await logAction(req.user.uid, "delete_user", "user", req.params.uid, {}, req.ip);
    res.json({ success: true, message: "User deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Delete failed" });
  }
};

// GET /api/admin/devices
const listAllDevices = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || "";
    const filter = search ? {
      $or: [
        { serial_number: { $regex: search, $options: "i" } },
        { assigned_tenant: { $regex: search, $options: "i" } },
      ]
    } : {};
    const devices = await Device.find(filter).sort({ created_at: -1 }).skip((page-1)*limit).limit(limit);
    const total = await Device.countDocuments(filter);
    res.json({ success: true, devices, total, page });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch devices" });
  }
};

// POST /api/admin/devices  — pre-register a device + generate pairing token
const createDevice = async (req, res) => {
  try {
    const { serial_number, firmware_version, assigned_tenant, device_secret } = req.body;
    if (!serial_number || !device_secret)
      return res.status(400).json({ success: false, message: "serial_number and device_secret required" });

    // Auto-increment device_id
    const last = await Device.findOne().sort({ device_id: -1 });
    const device_id = last ? last.device_id + 1 : 100001;

    const device_secret_hash = await bcrypt.hash(device_secret, 10);
    const device = await Device.create({
      device_id, serial_number, device_secret_hash,
      firmware_version: firmware_version || "v1.0.0",
      assigned_tenant: assigned_tenant || null,
    });

    // Generate 24h pairing token
    const token = uuidv4().replace(/-/g, "");
    const expires_at = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await PairingToken.create({ device_id, serial_number, token, expires_at, created_by: req.user.uid });

    await logAction(req.user.uid, "create_device", "device", String(device_id), { serial_number, assigned_tenant }, req.ip);
    res.status(201).json({ success: true, device, pairing_token: token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Device creation failed" });
  }
};

// PUT /api/admin/devices/:id
const updateDeviceAdmin = async (req, res) => {
  try {
    const updates = { ...req.body, updated_at: new Date() };
    delete updates.device_secret_hash;
    const device = await Device.findOneAndUpdate({ device_id: Number(req.params.id) }, updates, { new: true });
    await logAction(req.user.uid, "update_device", "device", req.params.id, req.body, req.ip);
    res.json({ success: true, device });
  } catch (err) {
    res.status(500).json({ success: false, message: "Update failed" });
  }
};

// DELETE /api/admin/devices/:id
const deleteDevice = async (req, res) => {
  try {
    const device_id = Number(req.params.id);
    await Device.deleteOne({ device_id });
    await DeviceMember.deleteMany({ device_id });
    await logAction(req.user.uid, "delete_device", "device", req.params.id, {}, req.ip);
    res.json({ success: true, message: "Device deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Delete failed" });
  }
};

// POST /api/admin/devices/:id/transfer
const transferOwnership = async (req, res) => {
  try {
    const device_id = Number(req.params.id);
    const { new_owner_email } = req.body;
    const newOwner = await User.findOne({ email: new_owner_email.toLowerCase() });
    if (!newOwner) return res.status(404).json({ success: false, message: "New owner not found" });

    const device = await Device.findOne({ device_id });
    const oldOwnerUid = device.owner_uid;

    // Update device
    device.owner_uid = newOwner.uid;
    device.updated_at = new Date();
    await device.save();

    // Downgrade old owner to member
    if (oldOwnerUid) await DeviceMember.updateOne({ device_id, user_uid: oldOwnerUid }, { role: "member" });

    // Upsert new owner
    await DeviceMember.findOneAndUpdate(
      { device_id, user_uid: newOwner.uid },
      { role: "owner", added_by: req.user.uid },
      { upsert: true }
    );

    await logAction(req.user.uid, "transfer_ownership", "device", req.params.id, { new_owner_email }, req.ip);
    res.json({ success: true, message: "Ownership transferred to " + newOwner.name });
  } catch (err) {
    res.status(500).json({ success: false, message: "Transfer failed" });
  }
};

// GET /api/admin/logs
const getAdminLogs = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const logs = await AdminLog.find().sort({ created_at: -1 }).skip((page-1)*limit).limit(limit);
    const total = await AdminLog.countDocuments();
    res.json({ success: true, logs, total, page });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch logs" });
  }
};

// GET /api/admin/feedlogs
const getAllFeedLogs = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const filter = {};
    if (req.query.device_id) filter.device_id = Number(req.query.device_id);
    const logs = await FeedLog.find(filter).sort({ triggered_at: -1 }).skip((page-1)*limit).limit(limit);
    const total = await FeedLog.countDocuments(filter);
    res.json({ success: true, logs, total, page });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch feed logs" });
  }
};


// Tenant Controllers
const listTenants = async (req, res) => {
  try {
    const tenants = await Tenant.find().sort({ name: 1 });
    res.json({ success: true, tenants });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch tenants" });
  }
};

const createTenant = async (req, res) => {
  try {
    const { name, display_name } = req.body;
    if (!name || !display_name)
      return res.status(400).json({ success: false, message: "name and display_name are required" });

    const existing = await Tenant.findOne({ name: name.toUpperCase() });
    if (existing) return res.status(409).json({ success: false, message: "Tenant name already exists" });

    const tenant = await Tenant.create({ name: name.toUpperCase(), display_name });
    await logAction(req.user.uid, "create_tenant", "system", name, { display_name }, req.ip);
    res.status(201).json({ success: true, tenant });
  } catch (err) {
    res.status(500).json({ success: false, message: "Tenant creation failed" });
  }
};

const deleteTenant = async (req, res) => {
  try {
    const { name } = req.params;
    await Tenant.deleteOne({ name });
    await logAction(req.user.uid, "delete_tenant", "system", name, {}, req.ip);
    res.json({ success: true, message: "Tenant deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Delete failed" });
  }
};

// Firmware Controllers
const listFirmwares = async (req, res) => {
  try {
    const firmwares = await Firmware.find().sort({ created_at: -1 });
    res.json({ success: true, firmwares });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch firmwares" });
  }
};

const createFirmware = async (req, res) => {
  try {
    const { version, changelog, esp_code, size_kb, is_latest } = req.body;
    if (!version || !changelog || !esp_code)
      return res.status(400).json({ success: false, message: "version, changelog, and esp_code are required" });

    const existing = await Firmware.findOne({ version });
    if (existing) return res.status(409).json({ success: false, message: "Firmware version already exists" });

    if (is_latest) {
      await Firmware.updateMany({ is_latest: true }, { is_latest: false });
    }

    const firmware = await Firmware.create({
      version,
      changelog,
      esp_code,
      size_kb: size_kb || 0,
      is_latest: is_latest || false
    });

    await logAction(req.user.uid, "create_firmware", "system", version, { size_kb, is_latest }, req.ip);
    res.status(201).json({ success: true, firmware });
  } catch (err) {
    res.status(500).json({ success: false, message: "Firmware creation failed" });
  }
};

const deleteFirmware = async (req, res) => {
  try {
    const { version } = req.params;
    await Firmware.deleteOne({ version });
    await logAction(req.user.uid, "delete_firmware", "system", version, {}, req.ip);
    res.json({ success: true, message: "Firmware deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Delete failed" });
  }
};

module.exports = {
  listTenants, createTenant, deleteTenant,
  listFirmwares, createFirmware, deleteFirmware,
  getStats, listUsers, updateUser, deleteUser, listAllDevices, createDevice, updateDeviceAdmin, deleteDevice, transferOwnership, getAdminLogs, getAllFeedLogs };
