const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const User = require("../models/User");
const OtpCode = require("../models/OtpCode");
const { signToken } = require("../utils/jwt");
const { generateOTP, otpExpiry } = require("../utils/otp");
const { sendOTP, sendWelcome } = require("../utils/email");

// POST /api/auth/send-otp
const sendOtp = async (req, res) => {
  try {
    const { email, type } = req.body;
    if (!email || !type) return res.status(400).json({ success: false, message: "Email and type required" });

    // 1.5 min cooldown check
    const recent = await OtpCode.findOne({ email: email.toLowerCase(), type })
      .sort({ created_at: -1 });
    if (recent) {
      const age = (Date.now() - new Date(recent.created_at).getTime()) / 1000;
      if (age < 90) {
        return res.status(429).json({
          success: false,
          message: "Please wait before requesting a new code",
          retryAfterSeconds: Math.ceil(90 - age),
        });
      }
    }

    const code = generateOTP();
    await OtpCode.create({
      email: email.toLowerCase(),
      code,
      type,
      expires_at: otpExpiry(15),
    });

    await sendOTP(email, code, type);
    res.json({ success: true, message: "OTP sent to " + email });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Failed to send OTP" });
  }
};

// POST /api/auth/verify-otp
const verifyOtp = async (req, res) => {
  try {
    const { email, code, type } = req.body;
    const otp = await OtpCode.findOne({
      email: email.toLowerCase(), code, type, verified: false,
    }).sort({ created_at: -1 });

    if (!otp || new Date(otp.expires_at) < new Date()) {
      return res.status(400).json({ success: false, message: "Invalid or expired OTP" });
    }
    otp.verified = true;
    await otp.save();
    res.json({ success: true, message: "OTP verified" });
  } catch (err) {
    res.status(500).json({ success: false, message: "OTP verification failed" });
  }
};

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ success: false, message: "All fields required" });

    // Check verified OTP
    const otp = await OtpCode.findOne({
      email: email.toLowerCase(), type: "signup", verified: true,
    }).sort({ created_at: -1 });
    if (!otp) return res.status(400).json({ success: false, message: "Email not verified. Please verify OTP first." });

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) return res.status(409).json({ success: false, message: "Email already registered" });

    const password_hash = await bcrypt.hash(password, 12);
    const uid = "usr_" + crypto.randomUUID().replace(/-/g, "").substring(0, 16);

    const user = await User.create({
      uid, name, email: email.toLowerCase(), password_hash,
      auth_providers: ["email"], email_verified: true,
    });

    await sendWelcome(email, name).catch(() => {});
    const token = signToken({ uid: user.uid, role: user.role });
    res.status(201).json({ success: true, token, user: { uid: user.uid, name, email: user.email, role: user.role } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Registration failed" });
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ success: false, message: "Email and password required" });

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || !user.password_hash)
      return res.status(401).json({ success: false, message: "Invalid credentials" });

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) return res.status(401).json({ success: false, message: "Invalid credentials" });
    if (!user.is_active) return res.status(403).json({ success: false, message: "Account deactivated" });

    user.last_login = new Date();
    await user.save();

    const token = signToken({ uid: user.uid, role: user.role });
    res.json({
      success: true, token,
      user: { uid: user.uid, name: user.name, email: user.email, role: user.role, avatar_url: user.avatar_url, auth_providers: user.auth_providers },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: "Login failed" });
  }
};

// POST /api/auth/social-login
const socialLogin = async (req, res) => {
  try {
    const { provider, email, name, avatar_url } = req.body;
    if (!provider || !email) return res.status(400).json({ success: false, message: "Provider and email required" });

    let user = await User.findOne({ email: email.toLowerCase() });
    if (user) {
      if (!user.auth_providers.includes(provider)) {
        user.auth_providers.push(provider);
        await user.save();
      }
    } else {
      const uid = "usr_" + crypto.randomUUID().replace(/-/g, "").substring(0, 16);
      user = await User.create({
        uid, name: name || email.split("@")[0],
        email: email.toLowerCase(), password_hash: null,
        auth_providers: [provider], email_verified: true,
        avatar_url: avatar_url || null,
      });
    }

    const token = signToken({ uid: user.uid, role: user.role });
    res.json({
      success: true, token,
      user: { uid: user.uid, name: user.name, email: user.email, role: user.role, avatar_url: user.avatar_url, auth_providers: user.auth_providers },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: "Social login failed" });
  }
};

// POST /api/auth/forgot-password  (send OTP)
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) return res.status(404).json({ success: false, message: "No account found with this email" });

    // reuse sendOtp logic
    req.body.type = "forgot_password";
    return sendOtp(req, res);
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to process request" });
  }
};

// POST /api/auth/reset-password
const resetPassword = async (req, res) => {
  try {
    const { email, password } = req.body;
    const otp = await OtpCode.findOne({
      email: email.toLowerCase(), type: "forgot_password", verified: true,
    }).sort({ created_at: -1 });
    if (!otp) return res.status(400).json({ success: false, message: "Please verify OTP first" });

    const hash = await bcrypt.hash(password, 12);
    await User.updateOne({ email: email.toLowerCase() }, { password_hash: hash });
    res.json({ success: true, message: "Password updated successfully" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Password reset failed" });
  }
};

// GET /api/auth/me
const getMe = async (req, res) => {
  res.json({ success: true, user: req.user });
};

module.exports = { sendOtp, verifyOtp, register, login, socialLogin, forgotPassword, resetPassword, getMe };
