import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Initialize the secure storage
  static const _storage = FlutterSecureStorage();
  static const _key = 'auth_token';

  // 1. Save token when user logs in
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _key, value: token);
  }

  // 2. Read token when app opens
  static Future<String?> getToken() async {
    return await _storage.read(key: _key);
  }

  // 3. Delete token when user logs out
  static Future<void> deleteToken() async {
    await _storage.delete(key: _key);
  }

  // 4. Check if user is logged in
  static Future<bool> isLoggedIn() async {
    String? token = await getToken();
    return token != null;
  }
}