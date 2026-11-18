import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Lưu access token trong bộ nhớ an toàn (Keychain / Keystore),
/// có cache trong RAM để interceptor không phải đọc đĩa mỗi request.
class TokenStorage {
  TokenStorage(this._secure);

  final FlutterSecureStorage _secure;
  String? _cache;
  bool _loaded = false;

  Future<String?> read() async {
    if (!_loaded) {
      _cache = await _secure.read(key: StorageKeys.accessToken);
      _loaded = true;
    }
    return _cache;
  }

  Future<void> save(String token) async {
    _cache = token;
    _loaded = true;
    await _secure.write(key: StorageKeys.accessToken, value: token);
  }

  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _secure.delete(key: StorageKeys.accessToken);
  }
}
