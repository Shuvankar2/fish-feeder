const router = require("express").Router();
const c = require("../controllers/auth.controller");
const { protect } = require("../middleware/auth");

router.post("/send-otp",       c.sendOtp);
router.post("/verify-otp",     c.verifyOtp);
router.post("/register",       c.register);
router.post("/login",          c.login);
router.post("/social-login",   c.socialLogin);
router.post("/forgot-password",c.forgotPassword);
router.post("/reset-password", c.resetPassword);
router.get("/me",              protect, c.getMe);
router.put("/me",              protect, c.updateMe);

module.exports = router;
