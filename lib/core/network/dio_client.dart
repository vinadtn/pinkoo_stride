import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/config/app_environment.dart';
import '../constants/app_constants.dart';
import '../logger/app_logger.dart';
import '../storage/token_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

abstract final class DioClient {
  static Dio create({
    required AppEnvironment env,
    required TokenStorage tokenStorage,
    required AppLogger logger,
    // Gọi khi server trả 401. Chưa có backend nên mặc định không làm gì.
    VoidCallback? onUnauthorized,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: env.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(tokenStorage, onUnauthorized: onUnauthorized ?? () {}),
    );
    if (env.enableLogging) dio.interceptors.add(LoggingInterceptor(logger));

    return dio;
  }
}
