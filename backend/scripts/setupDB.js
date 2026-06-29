require("dotenv").config({ path: require("path").resolve(__dirname, "../.env") });
const mongoose = require("mongoose");

// Import all models (this registers the schemas + indexes in MongoDB)
const User        = require("../models/User");
const Device      = require("../models/Device");
const DeviceMember= require("../models/DeviceMember");
const Schedule    = require("../models/Schedule");
const FeedLog     = require("../models/FeedLog");
const PairingToken= require("../models/PairingToken");
const OtpCode     = require("../models/OtpCode");
const AdminLog    = require("../models/AdminLog");
const Tenant      = require("../models/Tenant");
const Firmware    = require("../models/Firmware");

const setup = async () => {
  console.log("\n?? AquaGlass DB Setup Starting...\n");

  try {
    console.log("?? Connecting to MongoDB Atlas...");
    await mongoose.connect(process.env.MONGODB_URI);
    console.log(`? Connected to: ${mongoose.connection.host}`);
    console.log(`?? Database:    ${mongoose.connection.name}\n`);

    const models = [
      { name: "users",          model: User         },
      { name: "devices",        model: Device       },
      { name: "device_members", model: DeviceMember },
      { name: "schedules",      model: Schedule     },
      { name: "feed_logs",      model: FeedLog      },
      { name: "pairing_tokens", model: PairingToken },
      { name: "otpcodes",       model: OtpCode      },
      { name: "adminlogs",      model: AdminLog     },
      { name: "tenants",        model: Tenant       },
      { name: "firmwares",      model: Firmware     },
    ];

    console.log("?? Creating collections & syncing indexes...\n");

    for (const { name, model } of models) {
      await model.createIndexes();
      const count = await model.countDocuments();
      console.log(`  ? ${name.padEnd(20)} � indexes synced  (${count} documents)`);
    }

    console.log("\n?? All collections and indexes are ready!");
    console.log("?? Your MongoDB Atlas database is fully set up for AquaGlass.\n");

  } catch (err) {
    console.error("\n? Setup failed:", err.message);
    if (err.message.includes("authentication")) {
      console.error("?? Check your MONGODB_URI username/password in .env");
    }
    if (err.message.includes("network")) {
      console.error("?? Check your Network Access whitelist in MongoDB Atlas");
    }
    process.exit(1);
  } finally {
    await mongoose.connection.close();
    console.log("?? Connection closed.");
  }
};

setup();
