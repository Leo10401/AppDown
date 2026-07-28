require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");

const connectDB = require("../connection");
const userRoutes = require("../routes/UserRoutes");

const app = express();

// Trust Vercel's reverse proxy so express-rate-limit reads the real client IP
app.set("trust proxy", 1);

// ─── Security Middleware ─────────────────────────────────────────────────────

// Helmet sets various HTTP headers for security
app.use(helmet());

// CORS — permissive for mobile app; tighten in production
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// Parse JSON request bodies
app.use(express.json());

// ─── Rate Limiting ───────────────────────────────────────────────────────────

// Strict rate limit on auth endpoints to prevent abuse
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // max 20 requests per window per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many authentication attempts. Try again later." },
});

app.use("/auth", authLimiter);

// ─── Database Connection ─────────────────────────────────────────────────────

// Cache the connection promise so Vercel serverless reuses it across invocations
let isConnected = false;

app.use(async (req, res, next) => {
  if (!isConnected) {
    await connectDB();
    isConnected = true;
  }
  next();
});

// ─── Health Check ────────────────────────────────────────────────────────────

app.get("/", (req, res) => {
  res.json({
    status: "ok",
    service: "AppRunner Backend",
    timestamp: new Date().toISOString(),
  });
});

// ─── Routes ──────────────────────────────────────────────────────────────────

app.use("/", userRoutes);

// ─── Export for Vercel ───────────────────────────────────────────────────────

module.exports = app;
