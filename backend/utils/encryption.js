const crypto = require("crypto");

const ALGORITHM = "aes-256-gcm";

/**
 * Encrypt a plaintext string using AES-256-GCM.
 * @param {string} plaintext - The text to encrypt (e.g. a GitHub access token).
 * @returns {{ encrypted: string, iv: string, authTag: string }} Hex-encoded values.
 */
function encryptToken(plaintext) {
  const key = Buffer.from(process.env.ENCRYPTION_KEY, "hex");
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plaintext, "utf8", "hex");
  encrypted += cipher.final("hex");

  const authTag = cipher.getAuthTag().toString("hex");

  return {
    encrypted,
    iv: iv.toString("hex"),
    authTag,
  };
}

/**
 * Decrypt a previously encrypted string using AES-256-GCM.
 * @param {string} encrypted - Hex-encoded ciphertext.
 * @param {string} iv - Hex-encoded initialization vector.
 * @param {string} authTag - Hex-encoded authentication tag.
 * @returns {string} The original plaintext.
 */
function decryptToken(encrypted, iv, authTag) {
  const key = Buffer.from(process.env.ENCRYPTION_KEY, "hex");
  const decipher = crypto.createDecipheriv(
    ALGORITHM,
    key,
    Buffer.from(iv, "hex")
  );
  decipher.setAuthTag(Buffer.from(authTag, "hex"));

  let decrypted = decipher.update(encrypted, "hex", "utf8");
  decrypted += decipher.final("utf8");

  return decrypted;
}

module.exports = { encryptToken, decryptToken };
