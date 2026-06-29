const router = require("express").Router();
const c = require("../controllers/feedlog.controller");
const { protect } = require("../middleware/auth");

router.get("/:deviceId", protect, c.getLogs);

module.exports = router;
