import '../../l10n/gen/app_localizations.dart';
import 'failures.dart';

/// Đổi Failure → câu thông báo theo ngôn ngữ hiện tại (dùng ở tầng presentation).
///
/// Thêm mã lỗi mới từ backend: thêm chuỗi vào file .arb → thêm một dòng vào [_serverCode].
extension FailureMessage on Failure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    ServerFailure(:final code) => _serverCode(code, l10n) ?? l10n.errorServer,
    CacheFailure() || UnknownFailure() => l10n.errorGeneric,
  };

  static String? _serverCode(String? code, AppLocalizations l10n) => switch (code) {
    'INVALID_CREDENTIALS' => l10n.errorInvalidCredentials,
    'INVALID_CURRENT_PASSWORD' => l10n.errorInvalidCurrentPassword,
    'WEAK_PASSWORD' => l10n.errorWeakPassword,
    'SAME_PASSWORD' => l10n.validationPasswordSame,
    _ => null,
  };
}
