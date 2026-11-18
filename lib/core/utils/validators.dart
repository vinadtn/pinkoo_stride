import '../../l10n/gen/app_localizations.dart';

/// Hàm kiểm tra cho TextFormField. Trả về null nếu hợp lệ, ngược lại là câu báo lỗi.
///
/// ```dart
/// TextFormField(validator: (v) => Validators.email(v, context.l10n))
/// ```
abstract final class Validators {
  static const minPasswordLength = 6;
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, AppLocalizations l10n) =>
      (value == null || value.trim().isEmpty) ? l10n.validationRequired : null;

  static String? email(String? value, AppLocalizations l10n) {
    final error = required(value, l10n);
    if (error != null) return error;
    return _emailRegex.hasMatch(value!.trim()) ? null : l10n.validationEmail;
  }

  static String? password(String? value, AppLocalizations l10n) {
    final error = required(value, l10n);
    if (error != null) return error;
    return value!.length < minPasswordLength
        ? l10n.validationPasswordLength(minPasswordLength)
        : null;
  }
}
