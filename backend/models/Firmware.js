const mongoose = require("mongoose");

const firmwareSchema = new mongoose.Schema({
  version:      { type: String, required: true, unique: true },
  changelog:    { type: String, required: true },
  esp_code:     { type: String, required: true }, // Store ESP32 source code
  size_kb:      { type: Number, default: 0 },
  is_latest:    { type: Boolean, default: false },
  created_at:   { type: Date, default: Date.now },
});

module.exports = mongoose.model("Firmware", firmwareSchema);
