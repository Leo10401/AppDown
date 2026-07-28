const mongoose = require("mongoose");

const oauthStateSchema = new mongoose.Schema({
  state: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 600, // TTL — auto-delete after 10 minutes
  },
});

module.exports = mongoose.model("OAuthState", oauthStateSchema);
