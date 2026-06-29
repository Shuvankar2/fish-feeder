const mongoose = require("mongoose");

const deviceSchema = new mongoose.Schema({
  device_id:          { type: Number, required: true, unique: true },
  serial_number:      { type: String, required: true, unique: true },
  device_secret_hash: { type: String, required: true },
  firmware_version:   { type: String, default: "v1.0.0" },
  assigned_tenant:    { type: String, default: null },
  status: {
    type: String,
    enum: ["unprovisioned", "provisioned", "online", "offline"],
    default: "unprovisioned",
  },
  owner_uid:    { type: String, default: null },
  last_seen:    { type: Date, default: null },
  ip_address:   { type: String, default: null },
  notes:        { type: String, default: null },
  created_at:   { type: Date, default: Date.now },
  updated_at:   { type: Date, default: Date.now },
});

// device_id and serial_number indexes created automatically via unique:true above
deviceSchema.index({ owner_uid: 1 });

module.exports = mongoose.model("Device", deviceSchema);

