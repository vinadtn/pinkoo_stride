import '../error/failures.dart';

/// Kết quả trả về từ repository / use case: thành công ([Ok]) hoặc thất bại ([Err]).
///
/// Dùng pattern matching:
/// ```dart
/// switch (result) {
///   case Ok(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onErr, R Function(T value) onOk) => switch (this) {
    Ok(:final value) => onOk(value),
    Err(:final failure) => onErr(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
