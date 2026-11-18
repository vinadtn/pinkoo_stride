/// Tập trung toàn bộ path để tránh gõ string rải rác.
abstract final class AppRoutes {
  /// Tab 1 — bảng tin + lịch sử hoạt động của chính mình.
  static const feed = '/';

  /// Tab 2 — chọn chế độ (Chạy / Đi bộ / Bơi / Đạp xe).
  static const record = '/record';

  /// Màn đang ghi — toàn màn hình, KHÔNG nằm trong shell có tabbar: đang chạy
  /// mà bấm nhầm sang tab khác là mất mạch.
  static const recording = '/recording';

  /// Tab 3 — hồ sơ.
  static const profile = '/profile';

  static const settings = '/settings';

  static const activity = '/activity/:id';

  static String activityOf(int id) => '/activity/$id';
}
