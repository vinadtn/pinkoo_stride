import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../storage/token_storage.dart';

/// - Tự gắn `Authorization: Bearer <token>` nếu đã đăng nhập.
/// - Request CÓ token mà bị 401 → phiên hết hạn → gọi [onUnauthorized] (đăng xuất).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, {required this.onUnauthorized});

  final TokenStorage _tokenStorage;
  final VoidCallback onUnauthorized;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final hadToken = err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && hadToken) onUnauthorized();
    handler.next(err);
  }
}
