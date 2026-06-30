const mongoose = require("mongoose");

const tenantSchema = new mongoose.Schema({
  name:         { type: String, required: true, unique: true }, // unique code, e.g. "TENANT_A"
  display_name: { type: String, required: true },
  created_at:          { type: Date, default: Date.now },
  delete_requested_at: { type: Date, default: null },
});

module.exports = mongoose.models.Tenant || mongoose.model("Tenant", tenantSchema);