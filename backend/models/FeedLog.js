const mongoose = require("mongoose");

const feedLogSchema = new mongoose.Schema({
  device_id:    { type: Number, required: true },
  triggered_by: { type: String, default: null },
  trigger_type: { type: String, enum: ["manual", "schedule", "admin"], required: true },
  status:       { type: String, enum: ["success", "failed", "pending"], default: "pending" },
  amount_grams: { type: Number, default: 5 },
  note:         { type: String, default: null },
  triggered_at: { type: Date, default: Date.now },
});

feedLogSchema.index({ device_id: 1, triggered_at: -1 });

module.exports = mongoose.model("FeedLog", feedLogSchema);
