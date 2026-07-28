const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    githubId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    username: {
      type: String,
      required: true,
    },
    displayName: {
      type: String,
      default: null,
    },
    avatarUrl: {
      type: String,
      default: null,
    },
    email: {
      type: String,
      default: null,
    },
    // GitHub access token — stored AES-256-GCM encrypted
    encryptedGithubToken: {
      type: String,
      required: true,
    },
    tokenIv: {
      type: String,
      required: true,
    },
    tokenAuthTag: {
      type: String,
      required: true,
    },
  },
  {
    timestamps: true, // adds createdAt and updatedAt
  }
);

module.exports = mongoose.model("User", userSchema);
