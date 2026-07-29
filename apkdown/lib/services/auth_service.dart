import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages JWT token storage using secure device storage.
/// The JWT is never stored in plain SharedPreferences.
class AuthService {
  static const _tokenKey = 'app_jwt_token';
  static const _storage = FlutterSecureStorage();

  /// Save the JWT token securely.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieve the stored JWT token.
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Delete the stored JWT token (logout).
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Check if user is logged in (has a stored token).
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
