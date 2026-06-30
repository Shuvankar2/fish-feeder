const router = require("express").Router();
const c = require("../controllers/admin.controller");
const { protect } = require("../middleware/auth");
const { adminOnly } = require("../middleware/adminOnly");

const guard = [protect, adminOnly];

router.get("/stats",                   ...guard, c.getStats);
router.get("/users",                   ...guard, c.listUsers);
router.put("/users/:uid",              ...guard, c.updateUser);
router.delete("/users/:uid",           ...guard, c.deleteUser);
router.get("/devices",                 ...guard, c.listAllDevices);
router.post("/devices",                ...guard, c.createDevice);
router.put("/devices/:id",             ...guard, c.updateDeviceAdmin);
router.delete("/devices/:id",          ...guard, c.deleteDevice);
router.post("/devices/:id/transfer",   ...guard, c.transferOwnership);
router.get("/logs",                    ...guard, c.getAdminLogs);
router.get("/feedlogs",                ...guard, c.getAllFeedLogs);

// Tenant routes
router.get("/tenants",                 ...guard, c.listTenants);
router.post("/tenants",                ...guard, c.createTenant);
router.put("/tenants/:name",           ...guard, c.updateTenant);
router.post("/tenants/:name/delete-request", ...guard, c.requestDeleteTenant);
router.post("/tenants/:name/revoke-delete", ...guard, c.revokeDeleteTenant);
router.delete("/tenants/:name",        ...guard, c.deleteTenant);

// Firmware routes
router.get("/firmwares",               ...guard, c.listFirmwares);
router.post("/firmwares",              ...guard, c.createFirmware);
router.put("/firmwares/:version",      ...guard, c.updateFirmware);
router.post("/firmwares/:version/delete-request", ...guard, c.requestDeleteFirmware);
router.post("/firmwares/:version/revoke-delete", ...guard, c.revokeDeleteFirmware);
router.delete("/firmwares/:version",   ...guard, c.deleteFirmware);

module.exports = router;
