const router = require("express").Router();
const c = require("../controllers/user.controller");
const { protect } = require("../middleware/auth");

router.put("/profile",          protect, c.updateProfile);
router.put("/password",         protect, c.changePassword);
router.post("/link-provider",   protect, c.linkProvider);
router.post("/unlink-provider", protect, c.unlinkProvider);

module.exports = router;
