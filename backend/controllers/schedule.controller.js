const Schedule = require("../models/Schedule");
const DeviceMember = require("../models/DeviceMember");

const checkAccess = async (device_id, uid) => {
  const m = await DeviceMember.findOne({ device_id: Number(device_id), user_uid: uid });
  return m;
};

// GET /api/schedules/:deviceId
const getSchedules = async (req, res) => {
  try {
    const m = await checkAccess(req.params.deviceId, req.user.uid);
    if (!m) return res.status(403).json({ success: false, message: "Access denied" });
    const schedules = await Schedule.find({ device_id: Number(req.params.deviceId) });
    res.json({ success: true, schedules });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch schedules" });
  }
};

// POST /api/schedules/:deviceId
const upsertSchedule = async (req, res) => {
  try {
    const device_id = Number(req.params.deviceId);
    const m = await checkAccess(device_id, req.user.uid);
    if (!m || m.role === "viewer")
      return res.status(403).json({ success: false, message: "Insufficient permissions" });

    const { label, time, days, amount_grams, is_active } = req.body;
    const schedule = await Schedule.create({
      device_id, created_by: req.user.uid,
      label, time, days, amount_grams, is_active,
    });
    res.status(201).json({ success: true, schedule });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to save schedule" });
  }
};

// DELETE /api/schedules/:deviceId/:id
const deleteSchedule = async (req, res) => {
  try {
    const device_id = Number(req.params.deviceId);
    const m = await checkAccess(device_id, req.user.uid);
    if (!m || m.role === "viewer")
      return res.status(403).json({ success: false, message: "Insufficient permissions" });

    await Schedule.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: "Schedule deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to delete schedule" });
  }
};

module.exports = { getSchedules, upsertSchedule, deleteSchedule };
