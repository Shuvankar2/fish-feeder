const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  uid:              { type: String, required: true, unique: true },
  name:             { type: String, required: true },
  email:            { type: String, required: true, unique: true, lowercase: true },
  password_hash:    { type: String, default: null },
  avatar_url:       { type: String, default: null },
  role:             { type: String, enum: ["user", "admin"], default: "user" },
  auth_providers:   [{ type: String, enum: ["email", "google", "facebook"] }],
  email_verified:   { type: Boolean, default: false },
  is_active:        { type: Boolean, default: true },
  last_login:       { type: Date, default: null },
  created_at:       { type: Date, default: Date.now },
  updated_at:       { type: Date, default: Date.now },
});

// Indexes on email and uid are created automatically via unique:true above

module.exports = mongoose.model("User", userSchema);

