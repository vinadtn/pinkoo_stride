import 'package:flutter/material.dart';

/// BẢNG MÀU GỐC (raw colors) của Pinkoo Stride.
///
/// Port 1:1 từ biến CSS `:root` của prototype (`pinkoo-stride/index.html`), nên
/// app và prototype ra đúng một tông. Hậu tố `D` = bản dùng cho chế độ tối.
///
/// Đây là NƠI DUY NHẤT khai báo mã màu hex. Mọi chỗ khác (ColorScheme,
/// AppColors) chỉ tham chiếu tới đây.
///
/// KHÔNG dùng trực tiếp AppPalette trong widget. Trong widget hãy dùng:
///   context.colorScheme.primary   (màu chuẩn Material 3)
///   context.appColors.paper       (màu tuỳ biến, tự đổi theo sáng/tối)
abstract final class AppPalette {
  // ---- Nền (--paper / --surface / --sunken) ----
  static const Color paper = Color(0xFFFFF6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sunken = Color(0xFFFDEEF1);
  static const Color paperD = Color(0xFF1E1724);
  static const Color surfaceD = Color(0xFF2A2032);
  static const Color sunkenD = Color(0xFF352741);

  // ---- Chữ (--ink / --ink-2 / --ink-3) ----
  static const Color ink = Color(0xFF2E2233);
  static const Color ink2 = Color(0xFF6F5E6D);
  static const Color ink3 = Color(0xFFA08F9E);
  static const Color inkD = Color(0xFFFBEEF3);
  static const Color ink2D = Color(0xFFC3AFC0);
  static const Color ink3D = Color(0xFF95819A);

  // ---- Hồng Pinkoo (--pink / --pink-deep / --pink-soft) ----
  static const Color pink = Color(0xFFF2779B);
  static const Color pinkDeep = Color(0xFFCE3F6C);
  static const Color pinkSoft = Color(0xFFFFE0E8);
  static const Color pinkD = Color(0xFFFF8FAF);
  static const Color pinkDeepD = Color(0xFFFFB3C8);
  static const Color pinkSoftD = Color(0xFF4A2B3C);

  // ---- Xanh biển + bơ (--sky / --sky-soft / --butter) ----
  static const Color sky = Color(0xFF5FB2CE);
  static const Color skySoft = Color(0xFFDCF0F7);
  static const Color butter = Color(0xFFFFD79B);
  static const Color skyD = Color(0xFF8CCDE5);
  static const Color skySoftD = Color(0xFF28394A);
  static const Color butterD = Color(0xFFE8BE86);

  // ---- Đường kẻ (--line / --line-2) ----
  static const Color line = Color(0xFFF3DDE3);
  static const Color line2 = Color(0xFFE9CFD7);
  static const Color lineD = Color(0xFF3B2D46);
  static const Color line2D = Color(0xFF4A3856);

  // ---- Trung tính ----
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ---- Semantic ----
  /// Pin "S" điểm bắt đầu trong prototype (`.pin.start`).
  static const Color success = Color(0xFF3BA55D);
  static const Color successLight = Color(0xFF81C784);
  static const Color warning = Color(0xFFED6C02);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFEF9A9A);
  static const Color info = Color(0xFF0277BD);
  static const Color infoLight = Color(0xFF81D4FA);

  /// Phần đường đã tua qua khi xem lại (`.route-done`).
  static const Color routeDone = Color(0xFFFFC24D);
}
