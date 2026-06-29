const mongoose = require("mongoose");

const pairingTokenSchema = new mongoose.Schema({
  device_id:     { type: Number, required: true },
  serial_number: { type: String, required: true },
  token:         { type: String, required: true },
  used:          { type: Boolean, default: false },
  created_by:    { type: String, default: null },
  expires_at:    { type: Date, required: true },
  created_at:    { type: Date, default: Date.now },
});

// TTL index — MongoDB auto-deletes expired tokens
pairingTokenSchema.index({ expires_at: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model("PairingToken", pairingTokenSchema);
