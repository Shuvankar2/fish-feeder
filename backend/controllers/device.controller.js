const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const Device = require("../models/Device");
const DeviceMember = require("../models/DeviceMember");
const FeedLog = require("../models/FeedLog");
const User = require("../models/User");
const PairingToken = require("../models/PairingToken");

// GET /api/devices  — list all devices user has access to
const listDevices = async (req, res) => {
  try {
    const memberships = await DeviceMember.find({ user_uid: req.user.uid });
    const deviceIds = memberships.map((m) => m.device_id);
    const devices = await Device.find({ device_id: { $in: deviceIds } });

    const result = devices.map((d) => {
      const membership = memberships.find((m) => m.device_id === d.device_id);
      return { ...d.toObject(), user_role: membership?.role };
    });

    res.json({ success: true, devices: result });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch devices" });
  }
};

// POST /api/devices/claim
const claimDevice = async (req, res) => {
  try {
    const { device_id, serial_number, pairing_token } = req.body;

    // 1. Find token
    const pt = await PairingToken.findOne({
      device_id: Number(device_id),
      serial_number,
      token: pairing_token,
      used: false,
    });
    if (!pt || new Date(pt.expires_at) < new Date())
      return res.status(400).json({ success: false, message: "Invalid or expired pairing token" });

    // 2. Find device
    const device = await Device.findOne({ device_id: Number(device_id), serial_number });
    if (!device) return res.status(404).json({ success: false, message: "Device not found" });
    if (device.owner_uid)
      return res.status(409).json({ success: false, message: "Device already claimed by another user" });

    // 3. Assign ownership
    device.owner_uid = req.user.uid;
    device.status = "provisioned";
    device.updated_at = new Date();
    await device.save();

    // 4. Mark token used
    pt.used = true;
    await pt.save();

    // 5. Create device_members entry
    await DeviceMember.create({
      device_id: device.device_id,
      serial_number: device.serial_number,
      user_uid: req.user.uid,
      role: "owner",
    });

    res.json({ success: true, device: { ...device.toObject(), user_role: "owner" } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Claim failed" });
  }
};

// GET /api/devices/:id
const getDevice = async (req, res) => {
  try {
    const device = await Device.findOne({ device_id: Number(req.params.id) });
    if (!device) return res.status(404).json({ success: false, message: "Device not found" });

    const membership = await DeviceMember.findOne({ device_id: Number(req.params.id), user_uid: req.user.uid });
    if (!membership && req.user.role !== "admin")
      return res.status(403).json({ success: false, message: "Access denied" });

    res.json({ success: true, device: { ...device.toObject(), user_role: membership?.role } });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch device" });
  }
};

// PUT /api/devices/:id
const updateDevice = async (req, res) => {
  try {
    const membership = await DeviceMember.findOne({ device_id: Number(req.params.id), user_uid: req.user.uid });
    if (!membership || !["owner"].includes(membership.role))
      return res.status(403).json({ success: false, message: "Owner access required" });

    const { name, notes } = req.body;
    const updates = { updated_at: new Date() };
    if (name !== undefined) updates.name = name;
    if (notes !== undefined) updates.notes = notes;

    const device = await Device.findOneAndUpdate(
      { device_id: Number(req.params.id) }, updates, { new: true }
    );
    res.json({ success: true, device });
  } catch (err) {
    res.status(500).json({ success: false, message: "Update failed" });
  }
};

// POST /api/devices/:id/feed  — manual feed trigger
const triggerFeed = async (req, res) => {
  try {
    const device_id = Number(req.params.id);
    const membership = await DeviceMember.findOne({ device_id, user_uid: req.user.uid });
    if (!membership) return res.status(403).json({ success: false, message: "Access denied" });

    const { amount_grams = 5 } = req.body;
    const log = await FeedLog.create({
      device_id,
      triggered_by: req.user.uid,
      trigger_type: "manual",
      status: "success",
      amount_grams,
    });

    // TODO: publish to MQTT broker
    res.json({ success: true, log });
  } catch (err) {
    res.status(500).json({ success: false, message: "Feed trigger failed" });
  }
};

// GET /api/devices/:id/members
const getMembers = async (req, res) => {
  try {
    const device_id = Number(req.params.id);
    const myMembership = await DeviceMember.findOne({ device_id, user_uid: req.user.uid });
    if (!myMembership && req.user.role !== "admin")
      return res.status(403).json({ success: false, message: "Access denied" });

    const members = await DeviceMember.find({ device_id });
    const uids = members.map((m) => m.user_uid);
    const users = await User.find({ uid: { $in: uids } }).select("uid name email avatar_url");

    const result = members.map((m) => {
      const u = users.find((u) => u.uid === m.user_uid);
      return { ...m.toObject(), user: u };
    });

    res.json({ success: true, members: result });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch members" });
  }
};

// POST /api/devices/:id/members  — invite by email
const addMember = async (req, res) => {
  try {
    const device_id = Number(req.params.id);
    const ownerMembership = await DeviceMember.findOne({ device_id, user_uid: req.user.uid, role: "owner" });
    if (!ownerMembership) return res.status(403).json({ success: false, message: "Owner access required" });

    const { email, role = "member" } = req.body;
    const invitee = await User.findOne({ email: email.toLowerCase() });
    if (!invitee) return res.status(404).json({ success: false, message: "No user found with this email" });

    const existing = await DeviceMember.findOne({ device_id, user_uid: invitee.uid });
    if (existing) return res.status(409).json({ success: false, message: "User already has access to this device" });

    const device = await Device.findOne({ device_id });
    const member = await DeviceMember.create({
      device_id,
      serial_number: device.serial_number,
      user_uid: invitee.uid,
      role,
      added_by: req.user.uid,
    });

    res.json({ success: true, member, user: { uid: invitee.uid, name: invitee.name, email: invitee.email } });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to add member" });
  }
};

// DELETE /api/devices/:id/members/:uid
const removeMember = async (req, res) => {
  try {
    const device_id = Number(req.params.id);
    const ownerMembership = await DeviceMember.findOne({ device_id, user_uid: req.user.uid, role: "owner" });
    if (!ownerMembership) return res.status(403).json({ success: false, message: "Owner access required" });
    if (req.params.uid === req.user.uid)
      return res.status(400).json({ success: false, message: "Cannot remove yourself as owner" });

    await DeviceMember.deleteOne({ device_id, user_uid: req.params.uid });
    res.json({ success: true, message: "Member removed" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to remove member" });
  }
};

module.exports = { listDevices, claimDevice, getDevice, updateDevice, triggerFeed, getMembers, addMember, removeMember };
