const router = require("express").Router();
const c = require("../controllers/schedule.controller");
const { protect } = require("../middleware/auth");

router.get("/:deviceId",       protect, c.getSchedules);
router.post("/:deviceId",      protect, c.upsertSchedule);
router.delete("/:deviceId/:id",protect, c.deleteSchedule);

module.exports = router;
