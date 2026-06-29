const router = require("express").Router();
const c = require("../controllers/device.controller");
const { protect } = require("../middleware/auth");

router.get("/",                        protect, c.listDevices);
router.post("/claim",                  protect, c.claimDevice);
router.get("/:id",                     protect, c.getDevice);
router.put("/:id",                     protect, c.updateDevice);
router.post("/:id/feed",               protect, c.triggerFeed);
router.get("/:id/members",             protect, c.getMembers);
router.post("/:id/members",            protect, c.addMember);
router.delete("/:id/members/:uid",     protect, c.removeMember);

module.exports = router;
