import 'package:dio/dio.dart';

import '../error/failures.dart';

/// Đổi lỗi kỹ thuật của Dio → Failure của domain. Dùng trong repository impl.
///
/// Backend trả lỗi dạng `{ "code": "INVALID_CREDENTIALS", "message": "..." }`.
/// `code` được giữ trong [ServerFailure.code] để UI dịch ra câu thông báo.
extension DioErrorMapper on DioException {
  Failure toFailure() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(message);
      case DioExceptionType.badResponse:
        final status = response?.statusCode;
        final data = response?.data;
        final code = data is Map<String, dynamic> ? data['code'] as String? : null;
        final serverMessage = data is Map<String, dynamic> ? data['message'] as String? : null;

        if (status == 401 && (code == null || code == 'UNAUTHORIZED')) {
          return UnauthorizedFailure(serverMessage ?? message);
        }
        return ServerFailure(statusCode: status, code: code, message: serverMessage ?? message);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return UnknownFailure(message);
    }
  }
}
