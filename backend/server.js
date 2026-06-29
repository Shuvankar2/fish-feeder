// Load .env only in non-production (local dev). On Vercel, env vars are injected automatically.
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const express = require("express");
const cors = require("cors");
const connectDB = require("./config/database");

const app = express();

// Connect DB (serverless-safe - reuses existing connection)
connectDB();

// Middleware
app.use(cors({ origin: "*" }));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "AquaGlass Backend", timestamp: new Date().toISOString() });
});

// Routes
app.use("/api/auth", require("./routes/auth.routes"));
app.use("/api/users", require("./routes/user.routes"));
app.use("/api/devices", require("./routes/device.routes"));
app.use("/api/schedules", require("./routes/schedule.routes"));
app.use("/api/feedlogs", require("./routes/feedlog.routes"));
app.use("/api/admin", require("./routes/admin.routes"));

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.path} not found` });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: "Internal server error" });
});

const PORT = process.env.PORT || 5000;

// Only call app.listen when running locally (not on Vercel)
if (!process.env.VERCEL) {
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`\n🚀 AquaGlass Backend running on http://0.0.0.0:${PORT}`);
    console.log(`📡 Health: http://localhost:${PORT}/health`);
    console.log(`🔑 Auth:   http://localhost:${PORT}/api/auth`);
    console.log(`📦 Env:    ${process.env.NODE_ENV}\n`);
  });
}

// Export the Express app as a Vercel Serverless Function
module.exports = app;
