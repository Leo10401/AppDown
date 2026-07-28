const mongoose = require("mongoose");

const authCodeSchema = new mongoose.Schema({
  code: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    ref: "User",
  },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 120, // TTL — auto-delete after 2 minutes
  },
});

module.exports = mongoose.model("AuthCode", authCodeSchema);
