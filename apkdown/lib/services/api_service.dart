import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Centralized HTTP client for all backend API calls.
/// Handles JWT attachment and response parsing.
class ApiService {
  static const String _baseUrl = 'https://app-down-green.vercel.app';

  /// Get the authorization header with stored JWT.
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth Endpoints ──────────────────────────────────────────────────

  /// Get the GitHub OAuth authorization URL.
  static Future<String> getAuthUrl() async {
    final response = await http.get(Uri.parse('$_baseUrl/auth/github'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'];
    }
    throw Exception('Failed to get auth URL: ${response.body}');
  }

  /// Exchange a one-time auth code for a JWT.
  /// Returns a map with 'token' and 'user'.
  static Future<Map<String, dynamic>> exchangeAuthCode(String authCode) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'authCode': authCode}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to exchange auth code: ${response.body}');
  }

  // ─── Protected Endpoints ─────────────────────────────────────────────

  /// Get current user profile.
  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch profile: ${response.body}');
  }

  /// Get user's repositories.
  static Future<List<dynamic>> getRepositories() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repositories'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['repositories'];
    }
    throw Exception('Failed to fetch repositories: ${response.body}');
  }

  /// Get a specific repository.
  static Future<Map<String, dynamic>> getRepository(
    String owner,
    String repo,
  ) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repository/$owner/$repo'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['repository'];
    }
    throw Exception('Failed to fetch repository: ${response.body}');
  }

  /// Get branches for a repository.
  static Future<List<dynamic>> getBranches(String owner, String repo) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repository/$owner/$repo/branches'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['branches'];
    }
    throw Exception('Failed to fetch branches: ${response.body}');
  }

  /// Get commits for a repository.
  static Future<List<dynamic>> getCommits(String owner, String repo) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repository/$owner/$repo/commits'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['commits'];
    }
    throw Exception('Failed to fetch commits: ${response.body}');
  }

  /// Get issues for a repository.
  static Future<List<dynamic>> getIssues(String owner, String repo) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repository/$owner/$repo/issues'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['issues'];
    }
    throw Exception('Failed to fetch issues: ${response.body}');
  }

  /// Get releases for a repository (includes APK assets).
  static Future<List<dynamic>> getReleases(String owner, String repo) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repository/$owner/$repo/releases'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['releases'];
    }
    throw Exception('Failed to fetch releases: ${response.body}');
  }

  /// Get the stored JWT token for authenticated downloads.
  static Future<String?> getStoredToken() async {
    return await AuthService.getToken();
  }

  /// Get the AWS S3 redirect URL for a private release asset.
  static Future<String> getAssetDownloadUrl(String owner, String repo, int assetId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/repository/$owner/$repo/releases/assets/$assetId/download'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['downloadUrl'];
    }
    throw Exception('Failed to get download URL: ${response.body}');
  }

  /// Create a new release for a repository.
  static Future<void> createRelease(String owner, String repo, String version, String body) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/repository/$owner/$repo/releases'),
      headers: headers,
      body: jsonEncode({
        'tag_name': version,
        'name': 'Release $version',
        'body': body,
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to create release: ${response.body}');
    }
  }

  /// Logout — clears GitHub token on server side.
  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse('$_baseUrl/logout'), headers: headers);
    await AuthService.deleteToken();
  }
}
