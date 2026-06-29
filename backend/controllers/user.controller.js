const bcrypt = require("bcryptjs");
const User = require("../models/User");

// PUT /api/users/profile
const updateProfile = async (req, res) => {
  try {
    const { name, avatar_url } = req.body;
    const updates = {};
    if (name) updates.name = name;
    if (avatar_url !== undefined) updates.avatar_url = avatar_url;
    updates.updated_at = new Date();

    const user = await User.findOneAndUpdate(
      { uid: req.user.uid }, updates, { new: true, select: "-password_hash" }
    );
    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, message: "Profile update failed" });
  }
};

// PUT /api/users/password
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findOne({ uid: req.user.uid });
    if (!user.password_hash)
      return res.status(400).json({ success: false, message: "No password set (social login account)" });

    const match = await bcrypt.compare(currentPassword, user.password_hash);
    if (!match) return res.status(400).json({ success: false, message: "Current password incorrect" });

    user.password_hash = await bcrypt.hash(newPassword, 12);
    user.updated_at = new Date();
    await user.save();
    res.json({ success: true, message: "Password changed successfully" });
  } catch (err) {
    res.status(500).json({ success: false, message: "Password change failed" });
  }
};

// POST /api/users/link-provider
const linkProvider = async (req, res) => {
  try {
    const { provider } = req.body;
    const user = await User.findOne({ uid: req.user.uid });
    if (!user.auth_providers.includes(provider)) {
      user.auth_providers.push(provider);
      await user.save();
    }
    res.json({ success: true, auth_providers: user.auth_providers });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to link provider" });
  }
};

// POST /api/users/unlink-provider
const unlinkProvider = async (req, res) => {
  try {
    const { provider } = req.body;
    const user = await User.findOne({ uid: req.user.uid });
    if (user.auth_providers.length <= 1)
      return res.status(400).json({ success: false, message: "Cannot remove last login method" });

    user.auth_providers = user.auth_providers.filter((p) => p !== provider);
    await user.save();
    res.json({ success: true, auth_providers: user.auth_providers });
  } catch (err) {
    res.status(500).json({ success: false, message: "Failed to unlink provider" });
  }
};

module.exports = { updateProfile, changePassword, linkProvider, unlinkProvider };
