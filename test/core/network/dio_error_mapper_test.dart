import 'package:dio/dio.dart';
import 'package:pinkoo_stride/core/error/failures.dart';
import 'package:pinkoo_stride/core/network/dio_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _badResponse(int status, Object? data) {
  final options = RequestOptions(path: '/x');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<dynamic>(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  test('mất mạng → NetworkFailure', () {
    final e = DioException.connectionError(requestOptions: RequestOptions(), reason: 'x');
    expect(e.toFailure(), isA<NetworkFailure>());
  });

  test('401 kèm code nghiệp vụ → ServerFailure giữ code', () {
    final failure = _badResponse(401, {'code': 'INVALID_CREDENTIALS', 'message': 'm'}).toFailure();
    expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'INVALID_CREDENTIALS'));
  });

  test('401 UNAUTHORIZED → UnauthorizedFailure', () {
    final failure = _badResponse(401, {'code': 'UNAUTHORIZED'}).toFailure();
    expect(failure, isA<UnauthorizedFailure>());
  });

  test('500 không có body → ServerFailure', () {
    expect(_badResponse(500, null).toFailure(), isA<ServerFailure>());
  });
}
