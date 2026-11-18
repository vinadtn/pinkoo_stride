import 'package:equatable/equatable.dart';

/// Lỗi ở tầng domain — UI chỉ biết tới Failure, không biết Dio hay SQL.
sealed class Failure extends Equatable {
  const Failure([this.message]);

  final String? message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

final class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, this.code, String? message}) : super(message);

  final int? statusCode;

  /// Mã lỗi nghiệp vụ backend trả về, vd `INVALID_CREDENTIALS`, `WEAK_PASSWORD`.
  final String? code;

  @override
  List<Object?> get props => [statusCode, code, message];
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message]);
}

final class CacheFailure extends Failure {
  const CacheFailure([super.message]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message]);
}
