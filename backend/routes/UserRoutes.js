const express = require("express");
const axios = require("axios");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const User = require("../models/User");
const OAuthState = require("../models/OAuthState");
const AuthCode = require("../models/AuthCode");
const { encryptToken, decryptToken } = require("../utils/encryption");
const authenticateJWT = require("../middleware/auth");

const router = express.Router();

// ─── GitHub OAuth Constants ──────────────────────────────────────────────────
const GITHUB_AUTH_URL = "https://github.com/login/oauth/authorize";
const GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token";
const GITHUB_USER_URL = "https://api.github.com/user";
const GITHUB_API_BASE = "https://api.github.com";
const SCOPES = "read:user repo";
const JWT_EXPIRY = "7d";
const DEEP_LINK_SCHEME = "apprunner";

// ─────────────────────────────────────────────────────────────────────────────
// AUTH ROUTES (public)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * GET /auth/github
 *
 * Generates a GitHub OAuth authorization URL with a CSRF state token.
 * The mobile app should open this URL in a browser / WebView.
 */
router.get("/auth/github", async (req, res) => {
  try {
    // Generate a random state for CSRF protection
    const state = crypto.randomUUID();
    await OAuthState.create({ state });

    const params = new URLSearchParams({
      client_id: process.env.GITHUB_CLIENT_ID,
      redirect_uri: process.env.GITHUB_REDIRECT_URI,
      scope: SCOPES,
      state,
    });

    const authorizationUrl = `${GITHUB_AUTH_URL}?${params.toString()}`;

    return res.json({ url: authorizationUrl });
  } catch (error) {
    console.error("Error generating auth URL:", error.message);
    return res.status(500).json({ error: "Failed to initiate GitHub login." });
  }
});

/**
 * GET /auth/github/callback
 *
 * GitHub redirects here after the user authorizes.
 * Steps:
 *   1. Validate the state parameter (CSRF check).
 *   2. Exchange the authorization code for an access token.
 *   3. Fetch the user's GitHub profile.
 *   4. Create or update the local user record.
 *   5. Encrypt and store the GitHub access token.
 *   6. Generate a one-time auth code.
 *   7. Redirect to the mobile app deep link with the auth code.
 */
router.get("/auth/github/callback", async (req, res) => {
  const { code, state } = req.query;

  // --- Validate required query params ---
  if (!code || !state) {
    return res.status(400).json({ error: "Missing code or state parameter." });
  }

  try {
    // --- 1. Validate state (CSRF protection) ---
    const storedState = await OAuthState.findOneAndDelete({ state });
    if (!storedState) {
      return res
        .status(403)
        .json({ error: "Invalid or expired state. Possible CSRF attack." });
    }

    // --- 2. Exchange code for access token ---
    const tokenResponse = await axios.post(
      GITHUB_TOKEN_URL,
      {
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code,
        redirect_uri: process.env.GITHUB_REDIRECT_URI,
      },
      {
        headers: { Accept: "application/json" },
      }
    );

    const { access_token: accessToken, error: tokenError } =
      tokenResponse.data;

    if (tokenError || !accessToken) {
      console.error("GitHub token exchange error:", tokenResponse.data);
      return res
        .status(400)
        .json({ error: "Failed to exchange code for access token." });
    }

    // --- 3. Fetch GitHub user profile ---
    const userResponse = await axios.get(GITHUB_USER_URL, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: "application/vnd.github+json",
      },
    });

    const githubUser = userResponse.data;

    // --- 4. Encrypt the access token ---
    const { encrypted, iv, authTag } = encryptToken(accessToken);

    // --- 5. Upsert user (create or update) ---
    const user = await User.findOneAndUpdate(
      { githubId: String(githubUser.id) },
      {
        githubId: String(githubUser.id),
        username: githubUser.login,
        displayName: githubUser.name || null,
        avatarUrl: githubUser.avatar_url || null,
        email: githubUser.email || null,
        encryptedGithubToken: encrypted,
        tokenIv: iv,
        tokenAuthTag: authTag,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    // --- 6. Generate one-time auth code ---
    const authCode = crypto.randomUUID();
    await AuthCode.create({ code: authCode, userId: user._id });

    console.log(`✅ User authenticated: ${user.username} (${user.githubId})`);

    // --- 7. Redirect to mobile app deep link ---
    // The auth code is short-lived (2 min) and one-time use.
    // The Flutter app will exchange it for a JWT via POST /auth/token.
    const deepLink = `${DEEP_LINK_SCHEME}://login?authCode=${authCode}`;
    return res.redirect(deepLink);
  } catch (error) {
    console.error("OAuth callback error:", error.message);
    return res.status(500).json({ error: "Authentication failed." });
  }
});

/**
 * POST /auth/token
 *
 * Exchange a one-time auth code for a JWT.
 * The Flutter app calls this after receiving the deep link.
 */
router.post("/auth/token", async (req, res) => {
  const { authCode } = req.body;

  if (!authCode) {
    return res.status(400).json({ error: "Missing authCode." });
  }

  try {
    // Find and delete the auth code (one-time use)
    const storedCode = await AuthCode.findOneAndDelete({ code: authCode });

    if (!storedCode) {
      return res
        .status(403)
        .json({ error: "Invalid or expired authorization code." });
    }

    // Fetch the user linked to this auth code
    const user = await User.findById(storedCode.userId);
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }

    // Issue JWT
    const jwtPayload = {
      userId: user._id,
      githubId: user.githubId,
      username: user.username,
    };

    const token = jwt.sign(jwtPayload, process.env.JWT_SECRET, {
      expiresIn: JWT_EXPIRY,
    });

    console.log(`🔑 JWT issued for: ${user.username}`);

    return res.json({
      token,
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        email: user.email,
      },
    });
  } catch (error) {
    console.error("Token exchange error:", error.message);
    return res.status(500).json({ error: "Token exchange failed." });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PROTECTED ROUTES (JWT required)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Helper: Retrieve the decrypted GitHub token for the authenticated user.
 */
async function getGithubToken(userId) {
  const user = await User.findById(userId);
  if (!user) throw new Error("User not found.");
  return decryptToken(
    user.encryptedGithubToken,
    user.tokenIv,
    user.tokenAuthTag
  );
}

/**
 * Helper: Make an authenticated request to the GitHub API on behalf of the user.
 */
async function githubApiRequest(userId, endpoint) {
  const accessToken = await getGithubToken(userId);
  const response = await axios.get(`${GITHUB_API_BASE}${endpoint}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/vnd.github+json",
    },
  });
  return response.data;
}

// ── GET /me ──────────────────────────────────────────────────────────────────

router.get("/me", authenticateJWT, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select(
      "-encryptedGithubToken -tokenIv -tokenAuthTag"
    );
    if (!user) {
      return res.status(404).json({ error: "User not found." });
    }
    return res.json({ user });
  } catch (error) {
    console.error("Error fetching user:", error.message);
    return res.status(500).json({ error: "Failed to fetch user profile." });
  }
});

// ── GET /repositories ────────────────────────────────────────────────────────

router.get("/repositories", authenticateJWT, async (req, res) => {
  try {
    const repos = await githubApiRequest(
      req.user.userId,
      "/user/repos?sort=updated&per_page=100"
    );
    return res.json({ repositories: repos });
  } catch (error) {
    console.error("Error fetching repositories:", error.message);
    return res.status(500).json({ error: "Failed to fetch repositories." });
  }
});

// ── GET /repository/:owner/:repo ─────────────────────────────────────────────

router.get("/repository/:owner/:repo", authenticateJWT, async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const data = await githubApiRequest(
      req.user.userId,
      `/repos/${owner}/${repo}`
    );
    return res.json({ repository: data });
  } catch (error) {
    console.error("Error fetching repository:", error.message);
    return res.status(500).json({ error: "Failed to fetch repository." });
  }
});

// ── GET /repository/:owner/:repo/branches ────────────────────────────────────

router.get(
  "/repository/:owner/:repo/branches",
  authenticateJWT,
  async (req, res) => {
    try {
      const { owner, repo } = req.params;
      const data = await githubApiRequest(
        req.user.userId,
        `/repos/${owner}/${repo}/branches`
      );
      return res.json({ branches: data });
    } catch (error) {
      console.error("Error fetching branches:", error.message);
      return res.status(500).json({ error: "Failed to fetch branches." });
    }
  }
);

// ── GET /repository/:owner/:repo/commits ─────────────────────────────────────

router.get(
  "/repository/:owner/:repo/commits",
  authenticateJWT,
  async (req, res) => {
    try {
      const { owner, repo } = req.params;
      const data = await githubApiRequest(
        req.user.userId,
        `/repos/${owner}/${repo}/commits`
      );
      return res.json({ commits: data });
    } catch (error) {
      console.error("Error fetching commits:", error.message);
      return res.status(500).json({ error: "Failed to fetch commits." });
    }
  }
);

// ── GET /repository/:owner/:repo/issues ──────────────────────────────────────

router.get(
  "/repository/:owner/:repo/issues",
  authenticateJWT,
  async (req, res) => {
    try {
      const { owner, repo } = req.params;
      const data = await githubApiRequest(
        req.user.userId,
        `/repos/${owner}/${repo}/issues`
      );
      return res.json({ issues: data });
    } catch (error) {
      console.error("Error fetching issues:", error.message);
      return res.status(500).json({ error: "Failed to fetch issues." });
    }
  }
);

// ── GET /repository/:owner/:repo/releases ────────────────────────────────────

router.get(
  "/repository/:owner/:repo/releases",
  authenticateJWT,
  async (req, res) => {
    try {
      const { owner, repo } = req.params;
      const data = await githubApiRequest(
        req.user.userId,
        `/repos/${owner}/${repo}/releases`
      );
      return res.json({ releases: data });
    } catch (error) {
      console.error("Error fetching releases:", error.message);
      return res.status(500).json({ error: "Failed to fetch releases." });
    }
  }
);
// ── GET /repository/:owner/:repo/releases/assets/:assetId ────────────────────

router.get(
  "/repository/:owner/:repo/releases/assets/:assetId",
  authenticateJWT,
  async (req, res) => {
    try {
      const { owner, repo, assetId } = req.params;
      const accessToken = await getGithubToken(req.user.userId);
      
      // Request the asset from GitHub
      await axios.get(
        `${GITHUB_API_BASE}/repos/${owner}/${repo}/releases/assets/${assetId}`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Accept: "application/octet-stream",
          },
          maxRedirects: 0, // Prevent axios from following the redirect to S3
        }
      );

      // If it doesn't redirect, something is wrong
      return res.status(500).json({ error: "Expected redirect to S3 URL" });
    } catch (error) {
      if (error.response && error.response.status === 302) {
        // GitHub redirected to AWS S3!
        const downloadUrl = error.response.headers.location;
        if (downloadUrl) {
          return res.redirect(downloadUrl);
        }
      }
      console.error("Error fetching release asset:", error.message);
      return res.status(500).json({ error: "Failed to fetch release asset." });
    }
  }
);

// ── POST /logout ─────────────────────────────────────────────────────────────

router.post("/logout", authenticateJWT, async (req, res) => {
  try {
    // Clear the stored GitHub token for this user
    await User.findByIdAndUpdate(req.user.userId, {
      encryptedGithubToken: "",
      tokenIv: "",
      tokenAuthTag: "",
    });

    console.log(`🚪 User logged out: ${req.user.username}`);
    return res.json({ message: "Logged out successfully." });
  } catch (error) {
    console.error("Error during logout:", error.message);
    return res.status(500).json({ error: "Logout failed." });
  }
});

module.exports = router;
