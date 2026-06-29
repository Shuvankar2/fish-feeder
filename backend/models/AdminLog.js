const mongoose = require("mongoose");

const adminLogSchema = new mongoose.Schema({
  admin_uid:   { type: String, required: true },
  action:      { type: String, required: true },
  target_type: { type: String, enum: ["device", "user", "system"], required: true },
  target_id:   { type: String, default: null },
  details:     { type: Object, default: {} },
  ip_address:  { type: String, default: null },
  created_at:  { type: Date, default: Date.now },
});

adminLogSchema.index({ admin_uid: 1, created_at: -1 });

module.exports = mongoose.models.AdminLog || mongoose.model("AdminLog", adminLogSchema);