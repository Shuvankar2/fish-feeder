const fs = require("fs");
const path = require("path");

module.exports = async (req, res) => {
  const info = {
    env: {
      NODE_ENV: process.env.NODE_ENV,
      VERCEL: process.env.VERCEL,
      MONGODB_URI: process.env.MONGODB_URI ? "present (masked)" : "missing",
      JWT_SECRET: process.env.JWT_SECRET ? "present (masked)" : "missing",
      EMAIL_USER: process.env.EMAIL_USER ? "present (masked)" : "missing",
      EMAIL_PASS: process.env.EMAIL_PASS ? "present (masked)" : "missing",
    },
    cwd: process.cwd(),
    dirname: __dirname,
    filesInCwd: [],
    requireError: null,
  };

  try {
    info.filesInCwd = fs.readdirSync(process.cwd());
  } catch (err) {
    info.filesInCwd = `Error: ${err.message}`;
  }

  try {
    const serverPath = path.resolve(process.cwd(), "backend", "server.js");
    if (fs.existsSync(serverPath)) {
      info.backendServerExists = true;
      try {
        require("../backend/server.js");
        info.backendServerRequired = "success";
      } catch (requireErr) {
        info.requireError = {
          message: requireErr.message,
          stack: requireErr.stack,
        };
      }
    } else {
      info.backendServerExists = false;
    }
  } catch (err) {
    info.requireError = `Resolve/check error: ${err.message}`;
  }

  res.status(200).json(info);
};
