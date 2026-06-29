require("dotenv").config({ path: require("path").resolve(__dirname, "../.env") });
const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const User = require("../models/User");
const Device = require("../models/Device");
const DeviceMember = require("../models/DeviceMember");
const Schedule = require("../models/Schedule");
const FeedLog = require("../models/FeedLog");
const AdminLog = require("../models/AdminLog");
const Tenant = require("../models/Tenant");
const Firmware = require("../models/Firmware");

const seed = async () => {
  console.log("\n🌱 AquaGlass DB Seeding Starting...\n");

  try {
    console.log("Connecting to MongoDB Atlas...");
    await mongoose.connect(process.env.MONGODB_URI);
    console.log(`Connected to: ${mongoose.connection.host}`);
    console.log(`Database:    ${mongoose.connection.name}\n`);

    // 1. Seed Users
    const passwordHashUser = await bcrypt.hash("user123", 12);
    const passwordHashAdmin = await bcrypt.hash("admin123", 12);

    const usersToSeed = [
      {
        uid: "admin_uid_default",
        name: "Super Admin",
        email: "admin@email.com",
        password_hash: passwordHashAdmin,
        role: "admin",
        auth_providers: ["email"],
        email_verified: true,
        is_active: true
      },
      {
        uid: "usr_shuvankardebnath",
        name: "Shuvankar Debnath",
        email: "shuvankar345@gmail.com",
        password_hash: passwordHashUser,
        role: "user",
        auth_providers: ["email"],
        email_verified: true,
        is_active: true
      },
      {
        uid: "usr_johndoe",
        name: "John Doe",
        email: "john.doe@email.com",
        password_hash: passwordHashUser,
        role: "user",
        auth_providers: ["email"],
        email_verified: true,
        is_active: true
      },
      {
        uid: "usr_janesmith",
        name: "Jane Smith",
        email: "jane.smith@email.com",
        password_hash: passwordHashUser,
        role: "user",
        auth_providers: ["email"],
        email_verified: true,
        is_active: true
      }
    ];

    console.log("Seeding Users (Upserting)...");
    for (const u of usersToSeed) {
      const exists = await User.findOne({ email: u.email });
      if (!exists) {
        await User.create(u);
        console.log(`  + Created user: ${u.email} (${u.role})`);
      } else {
        console.log(`  . User already exists: ${u.email}`);
      }
    }

    // 2. Seed Devices
    const devicesToSeed = [
      {
        device_id: 100001,
        serial_number: "AQ2606001",
        device_secret_hash: await bcrypt.hash("sec100001", 12),
        firmware_version: "v1.0.1",
        assigned_tenant: "AQUA_GLASS_HQ",
        status: "online",
        owner_uid: "usr_shuvankardebnath",
        notes: "Main home tank feeder",
        ip_address: "192.168.1.55"
      },
      {
        device_id: 100002,
        serial_number: "AQ2606002",
        device_secret_hash: await bcrypt.hash("sec100002", 12),
        firmware_version: "v1.0.1",
        assigned_tenant: "TENANT_A",
        status: "online",
        owner_uid: "usr_shuvankardebnath",
        notes: "Office desk goldfish bowl",
        ip_address: "192.168.1.56"
      },
      {
        device_id: 100003,
        serial_number: "AQ2606003",
        device_secret_hash: await bcrypt.hash("sec100003", 12),
        firmware_version: "v1.0.0",
        assigned_tenant: "TENANT_B",
        status: "offline",
        owner_uid: "usr_johndoe",
        notes: "Living room marine aquarium"
      },
      {
        device_id: 100004,
        serial_number: "AQ2606004",
        device_secret_hash: await bcrypt.hash("sec100004", 12),
        firmware_version: "v1.0.0",
        assigned_tenant: null,
        status: "unprovisioned",
        owner_uid: null,
        notes: "New stock - warehouse"
      }
    ];

    console.log("\nSeeding Devices...");
    for (const d of devicesToSeed) {
      const exists = await Device.findOne({ device_id: d.device_id });
      if (!exists) {
        await Device.create(d);
        console.log(`  + Created device: ${d.device_id} (${d.serial_number})`);
      } else {
        console.log(`  . Device already exists: ${d.device_id}`);
      }
    }

    // 3. Seed Device Members (Sharing)
    const membersToSeed = [
      {
        device_id: 100001,
        serial_number: "AQ2606001",
        user_uid: "usr_janesmith",
        role: "member",
        added_by: "usr_shuvankardebnath"
      }
    ];

    console.log("\nSeeding Device Members...");
    for (const m of membersToSeed) {
      const exists = await DeviceMember.findOne({ device_id: m.device_id, user_uid: m.user_uid });
      if (!exists) {
        await DeviceMember.create(m);
        console.log(`  + Shared device ${m.device_id} with member ${m.user_uid}`);
      } else {
        console.log(`  . Sharing entry already exists for device ${m.device_id} with member ${m.user_uid}`);
      }
    }

    // 4. Seed Schedules
    const schedulesToSeed = [
      {
        device_id: 100001,
        created_by: "usr_shuvankardebnath",
        label: "Morning Feed",
        time: "08:00",
        days: ["Mon", "Wed", "Fri"],
        amount_grams: 5,
        is_active: true
      },
      {
        device_id: 100001,
        created_by: "usr_shuvankardebnath",
        label: "Evening Feed",
        time: "18:00",
        days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        amount_grams: 8,
        is_active: true
      },
      {
        device_id: 100002,
        created_by: "usr_shuvankardebnath",
        label: "Noon Snack",
        time: "12:30",
        days: ["Tue", "Thu"],
        amount_grams: 4,
        is_active: true
      },
      {
        device_id: 100003,
        created_by: "usr_johndoe",
        label: "Daily Feeding",
        time: "09:00",
        days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        amount_grams: 10,
        is_active: true
      }
    ];

    console.log("\nSeeding Schedules...");
    for (const s of schedulesToSeed) {
      const exists = await Schedule.findOne({ device_id: s.device_id, time: s.time, label: s.label });
      if (!exists) {
        await Schedule.create(s);
        console.log(`  + Created schedule: "${s.label}" for device ${s.device_id}`);
      } else {
        console.log(`  . Schedule already exists: "${s.label}" for device ${s.device_id}`);
      }
    }

    // 5. Seed Feed Logs (Historical entries for charts)
    console.log("\nSeeding Feed Logs...");
    const baseDate = new Date();
    // Check if feed logs already exist
    const logCount = await FeedLog.countDocuments();
    if (logCount < 10) {
      const triggers = ["manual", "schedule", "admin"];
      
      for (let i = 1; i <= 30; i++) {
        const triggeredAt = new Date(baseDate);
        triggeredAt.setHours(triggeredAt.getHours() - (i * 4)); // space logs every 4 hours

        // Device 100001
        await FeedLog.create({
          device_id: 100001,
          triggered_by: i % 3 === 0 ? "admin_uid_default" : "usr_shuvankardebnath",
          trigger_type: triggers[i % triggers.length],
          status: i % 15 === 0 ? "failed" : "success",
          amount_grams: (i % 3 === 0) ? 6 : 5,
          triggered_at: triggeredAt,
          note: i % 15 === 0 ? "Feeder jammed or empty" : "Fish fed successfully"
        });

        // Device 100002
        if (i % 2 === 0) {
          await FeedLog.create({
            device_id: 100002,
            triggered_by: "usr_shuvankardebnath",
            trigger_type: triggers[i % triggers.length],
            status: "success",
            amount_grams: 4,
            triggered_at: triggeredAt
          });
        }

        // Device 100003
        if (i % 3 === 0) {
          await FeedLog.create({
            device_id: 100003,
            triggered_by: "usr_johndoe",
            trigger_type: "schedule",
            status: i % 9 === 0 ? "failed" : "success",
            amount_grams: 8,
            triggered_at: triggeredAt
          });
        }
      }
      console.log(`  + Created 30 days of historical feed logs for devices.`);
    } else {
      console.log(`  . Database already contains ${logCount} feed logs. Skipping history generation.`);
    }

    // 6. Seed Admin Logs (Audit trail)
    console.log("\nSeeding Admin Logs...");
    const adminLogsToSeed = [
      {
        admin_uid: "admin_uid_default",
        action: "Pre-registered Device AQ2606004",
        target_type: "device",
        target_id: "100004",
        details: { model: "AquaGlass v1.0", assigned_tenant: null },
        ip_address: "127.0.0.1"
      },
      {
        admin_uid: "admin_uid_default",
        action: "Updated role for jane.smith@email.com to User",
        target_type: "user",
        target_id: "usr_janesmith",
        details: { previous_role: "user", new_role: "user" },
        ip_address: "127.0.0.1"
      },
      {
        admin_uid: "admin_uid_default",
        action: "Assigned Device AQ2606001 to tenant AQUA_GLASS_HQ",
        target_type: "device",
        target_id: "100001",
        details: { assigned_tenant: "AQUA_GLASS_HQ" },
        ip_address: "127.0.0.1"
      }
    ];

    for (const l of adminLogsToSeed) {
      const exists = await AdminLog.findOne({ action: l.action, target_id: l.target_id });
      if (!exists) {
        await AdminLog.create(l);
        console.log(`  + Logged admin action: "${l.action}"`);
      } else {
        console.log(`  . Admin log already exists: "${l.action}"`);
      }
    }

    
    // Seed Tenants
    console.log("\nSeeding Tenants...");
    const tenantsToSeed = [
      { name: "AQUA_GLASS_HQ", display_name: "AquaGlass HQ" },
      { name: "TENANT_A", display_name: "Beta Testing Labs" },
      { name: "TENANT_B", display_name: "Corporate Aquarium" }
    ];

    for (const t of tenantsToSeed) {
      const exists = await Tenant.findOne({ name: t.name });
      if (!exists) {
        await Tenant.create(t);
        console.log(`  + Created tenant: ${t.display_name} (${t.name})`);
      } else {
        console.log(`  . Tenant already exists: ${t.name}`);
      }
    }

    // Seed Firmwares
    console.log("\nSeeding Firmwares...");
    const firmwaresToSeed = [
      {
        version: "v1.0.4",
        changelog: "• Fixed auto-feed timer drift\n• Improved MQTT reconnect stability\n• Added food level calibration mode\n• Memory leak fix in WiFi handler",
        esp_code: "// AquaGlass Firmware v1.0.4\n#include <WiFi.h>\n#include <PubSubClient.h>\n\nvoid setup() {\n  Serial.begin(115200);\n  Serial.println(\"AquaGlass v1.0.4 Initializing...\");\n}\n\nvoid loop() {\n  // Monitor water and dispense feed\n}",
        size_kb: 248,
        is_latest: true
      },
      {
        version: "v1.0.3",
        changelog: "• Vacation mode implemented\n• Multi-schedule support (up to 10/day)\n• OTA over Cloud added",
        esp_code: "// AquaGlass Firmware v1.0.3\nvoid setup() {\n  // v1.0.3 init\n}",
        size_kb: 231,
        is_latest: false
      },
      {
        version: "v1.0.2",
        changelog: "• Initial cloud connect support\n• Manual feed button fix\n• Low food alert threshold configurable",
        esp_code: "// AquaGlass Firmware v1.0.2\nvoid setup() {\n  // v1.0.2 init\n}",
        size_kb: 198,
        is_latest: false
      },
      {
        version: "v1.0.1",
        changelog: "• Base release\n• Local WiFi control\n• Basic schedule (3/day)",
        esp_code: "// AquaGlass Firmware v1.0.1\nvoid setup() {\n  // v1.0.1 init\n}",
        size_kb: 172,
        is_latest: false
      }
    ];

    for (const f of firmwaresToSeed) {
      const exists = await Firmware.findOne({ version: f.version });
      if (!exists) {
        await Firmware.create(f);
        console.log(`  + Created firmware version: ${f.version}`);
      } else {
        console.log(`  . Firmware version already exists: ${f.version}`);
      }
    }

    console.log("\n🎉 AquaGlass database seeding completed successfully!");

  } catch (err) {
    console.error("\n❌ Seeding failed:", err.stack);
  } finally {
    await mongoose.connection.close();
    console.log("Connection closed.");
  }
};

seed();
