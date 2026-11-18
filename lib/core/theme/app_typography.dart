import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font chữ và cỡ chữ dùng chung.
///
/// Hai họ font, đúng như prototype:
/// - **Baloo 2** (`--display`) — tiêu đề và mọi con số to, nét tròn, cute.
/// - **Be Vietnam Pro** (`--body`) — nội dung, dấu tiếng Việt gọn gàng.
///
/// Màu chữ KHÔNG khai báo ở đây — ThemeData tự gán theo ColorScheme (sáng/tối).
abstract final class AppTypography {
  /// Font nội dung. `google_fonts` tải về và cache lần đầu có mạng.
  static TextStyle get _body => GoogleFonts.beVietnamPro();

  /// Font tiêu đề / số.
  static TextStyle get _display => GoogleFonts.baloo2();

  /// Chữ số đều bề ngang (class `.tnum` của prototype) — bắt buộc cho đồng hồ
  /// và pace đang chạy, không thì số nhảy làm layout giật.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Số liệu lớn kiểu `.bigstats .v` — Baloo 2 đậm, chữ số không giật.
  static TextStyle stat({required double fontSize, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.baloo2(
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.05,
        fontFeatures: tabular,
      );

  static TextTheme get textTheme => TextTheme(
    displayLarge: _display.copyWith(fontSize: 57, fontWeight: FontWeight.w800, height: 1.12),
    displayMedium: _display.copyWith(fontSize: 45, fontWeight: FontWeight.w800, height: 1.16),
    displaySmall: _display.copyWith(fontSize: 36, fontWeight: FontWeight.w800, height: 1.22),
    // .dhead h1 của prototype: 25–34px, w800
    headlineLarge: _display.copyWith(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1),
    headlineMedium: _display.copyWith(fontSize: 27, fontWeight: FontWeight.w800, height: 1.15),
    headlineSmall: _display.copyWith(fontSize: 23, fontWeight: FontWeight.w700, height: 1.2),
    // .sectionhead h2: 21px, w700
    titleLarge: _display.copyWith(fontSize: 21, fontWeight: FontWeight.w700, height: 1.27),
    // .act h3: 17px, w700
    titleMedium: _display.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35),
    titleSmall: _body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.43),
    // body mặc định của prototype là 15px
    bodyLarge: _body.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: _body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: _body.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge: _body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.43),
    labelMedium: _body.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.33),
    // .eyebrow / .bigstats .k: 10.5–11px, in hoa, giãn chữ
    labelSmall: _body.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      height: 1.45,
      letterSpacing: 1.1,
    ),
  );
}
