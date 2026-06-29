const mongoose = require("mongoose");

const otpSchema = new mongoose.Schema({
  email:      { type: String, required: true, lowercase: true },
  code:       { type: String, required: true },
  type:       { type: String, enum: ["signup", "forgot_password"], required: true },
  verified:   { type: Boolean, default: false },
  attempts:   { type: Number, default: 0 },
  expires_at: { type: Date, required: true },
  created_at: { type: Date, default: Date.now },
});

// TTL index — MongoDB auto-deletes expired OTPs
otpSchema.index({ expires_at: 1 }, { expireAfterSeconds: 0 });
otpSchema.index({ email: 1, type: 1 });

module.exports = mongoose.model("OtpCode", otpSchema);
