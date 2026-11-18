import '../utils/result.dart';

/// Mỗi use case làm đúng MỘT việc nghiệp vụ.
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Dùng cho use case không cần tham số.
final class NoParams {
  const NoParams();
}
