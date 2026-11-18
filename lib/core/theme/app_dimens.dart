/// Khoảng cách, bo góc dùng chung (thang 4pt).
abstract final class AppDimens {
  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;

  /// Bo góc card — biến `--r:18px` của prototype.
  static const double radiusLg = 18;

  /// Pill / nút bo tròn hết (`border-radius:999px`).
  static const double radiusPill = 999;

  // Size
  static const double buttonHeight = 48;

  /// Nút Dừng / Tạm dừng khi đang ghi — đủ to để bấm lúc đang chạy.
  static const double recordButtonSize = 76;
}
