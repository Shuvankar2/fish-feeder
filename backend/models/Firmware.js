const mongoose = require("mongoose");

const firmwareSchema = new mongoose.Schema({
  version:             { type: String, required: true, unique: true },
  changelog:           { type: String, required: true },
  esp_code:            { type: String, required: true }, // Store ESP32 source code
  size_kb:             { type: Number, default: 0 },
  tag:                 { type: String, enum: ['stable', 'test'], default: 'stable' },
  delete_requested_at: { type: Date, default: null },
  created_at:          { type: Date, default: Date.now },
});

module.exports = mongoose.models.Firmware || mongoose.model("Firmware", firmwareSchema);