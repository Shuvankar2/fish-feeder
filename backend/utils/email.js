const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendOTP = async (to, code, type) => {
  const subject = type === "signup"
    ? "AquaGlass — Verify Your Email"
    : "AquaGlass — Password Reset Code";

  const action = type === "signup"
    ? "complete your registration"
    : "reset your password";

  await transporter.sendMail({
    from: `"AquaGlass" <${process.env.EMAIL_USER}>`,
    to,
    subject,
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:auto;background:#0A221A;color:#fff;border-radius:16px;padding:32px;">
        <h2 style="color:#00FF87;margin:0 0 8px">AquaGlass 🐟</h2>
        <p style="color:#aaa;margin:0 0 24px">Smart Fish Feeder Platform</p>
        <p>Use the code below to ${action}. It expires in <strong>15 minutes</strong>.</p>
        <div style="background:#0D3325;border:1px solid #00FF8740;border-radius:12px;padding:24px;text-align:center;margin:24px 0;">
          <span style="font-size:40px;font-weight:bold;letter-spacing:12px;color:#00FF87">${code}</span>
        </div>
        <p style="color:#888;font-size:13px;">If you did not request this, you can safely ignore this email.</p>
      </div>
    `,
  });
};

const sendWelcome = async (to, name) => {
  await transporter.sendMail({
    from: `"AquaGlass" <${process.env.EMAIL_USER}>`,
    to,
    subject: "Welcome to AquaGlass!",
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:auto;background:#0A221A;color:#fff;border-radius:16px;padding:32px;">
        <h2 style="color:#00FF87">Welcome, ${name}! 🎉</h2>
        <p>Your AquaGlass account is ready. Connect your ESP32 device and start feeding smarter.</p>
        <p style="color:#888;font-size:13px;">AquaGlass — Smart Fish Feeder Platform</p>
      </div>
    `,
  });
};

module.exports = { sendOTP, sendWelcome };
