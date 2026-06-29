const mongoose = require("mongoose");

const scheduleSchema = new mongoose.Schema({
  device_id:    { type: Number, required: true },
  created_by:   { type: String, required: true },
  label:        { type: String, default: "Feeding Schedule" },
  time:         { type: String, required: true },
  days:         [{ type: String, enum: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"] }],
  amount_grams: { type: Number, default: 5 },
  is_active:    { type: Boolean, default: true },
  created_at:   { type: Date, default: Date.now },
  updated_at:   { type: Date, default: Date.now },
});

scheduleSchema.index({ device_id: 1 });

module.exports = mongoose.model("Schedule", scheduleSchema);
