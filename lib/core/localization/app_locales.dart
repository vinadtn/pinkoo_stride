import 'package:flutter/widgets.dart';

/// Danh sách ngôn ngữ và quy tắc chọn ngôn ngữ.
///
/// Thêm ngôn ngữ mới: tạo `lib/l10n/arb/app_<code>.arb` → thêm hằng số vào [all]
/// và tên hiển thị trong [displayName].
abstract final class AppLocales {
  static const vi = Locale('vi');
  static const en = Locale('en');

  /// Ngôn ngữ dùng khi thiết bị đặt một ngôn ngữ app không hỗ trợ.
  static const fallback = vi;

  /// Thứ tự hiển thị trong màn Cài đặt.
  static const all = [vi, en];

  static String displayName(Locale locale) => switch (locale.languageCode) {
    'vi' => 'Tiếng Việt',
    'en' => 'English',
    _ => locale.languageCode,
  };

  /// Dùng cho `MaterialApp.localeResolutionCallback`.
  static Locale resolve(Locale? locale, Iterable<Locale> supported) {
    if (locale == null) return fallback;
    for (final s in supported) {
      if (s.languageCode == locale.languageCode) return s;
    }
    return fallback;
  }
}
