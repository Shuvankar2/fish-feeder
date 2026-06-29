const FeedLog = require("../models/FeedLog");
const DeviceMember = require("../models/DeviceMember");

// GET /api/feedlogs/:deviceId?page=1&limit=20&date=2026-06-28
const getLogs = async (req, res) => {
  try {
    const device_id = Number(req.params.deviceId);
    const m = await DeviceMember.findOne({ device_id, user_uid: req.user.uid });
    if (!m && req.user.role !== "admin")
      return res.status(403).json({ success: false, message: "Access denied" });

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const filter = { device_id };
    if (req.query.date) {
      const d = new Date(req.query.date);
      const next = new Date(d);
      next.setDate(next.getDate() + 1);
      filter.triggered_at = { $gte: d, $lt: next };
    }

    const [logs, total] = await Promise.all([
      FeedLog.find(filter).sort({ triggered_at: -1 }).skip(skip).limit(limit),
      FeedLog.countDocuments(filter),
    ]);

    res.json({ success: true, logs, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to fetch logs" });
  }
};

module.exports = { getLogs };
