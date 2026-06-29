const { verifyToken } = require("../utils/jwt");
const User = require("../models/User");

const protect = async (req, res, next) => {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ success: false, message: "Unauthorized" });
  }
  const token = header.split(" ")[1];
  const decoded = verifyToken(token);
  if (!decoded) {
    return res.status(401).json({ success: false, message: "Invalid or expired token" });
  }
  const user = await User.findOne({ uid: decoded.uid }).select("-password_hash");
  if (!user || !user.is_active) {
    return res.status(401).json({ success: false, message: "User not found or deactivated" });
  }
  req.user = user;
  next();
};

module.exports = { protect };
