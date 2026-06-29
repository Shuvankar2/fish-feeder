const mongoose = require("mongoose");

const deviceMemberSchema = new mongoose.Schema({
  device_id:    { type: Number, required: true },
  serial_number:{ type: String, required: true },
  user_uid:     { type: String, required: true },
  role:         { type: String, enum: ["owner", "member", "viewer"], required: true },
  added_by:     { type: String, default: null },
  added_at:     { type: Date, default: Date.now },
});

deviceMemberSchema.index({ device_id: 1, user_uid: 1 }, { unique: true });
deviceMemberSchema.index({ user_uid: 1 });

module.exports = mongoose.models.DeviceMember || mongoose.model("DeviceMember", deviceMemberSchema);