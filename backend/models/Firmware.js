const mongoose = require("mongoose");

const firmwareSchema = new mongoose.Schema({
  version:             { type: String, required: true, unique: true },
  changelog:           { type: String, required: true },
  binary_data:         { type: String }, // Base64 encoded .bin file for real flashing
  esp_code:            { type: String }, // Optional source code reference
  size_kb:             { type: Number, default: 0 },
  tag:                 { type: String, enum: ['stable', 'test'], default: 'stable' },
  delete_requested_at: { type: Date, default: null },
  created_at:          { type: Date, default: Date.now },
});

module.exports = mongoose.models.Firmware || mongoose.model("Firmware", firmwareSchema);