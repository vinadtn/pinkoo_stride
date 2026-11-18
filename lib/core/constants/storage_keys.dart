/// Key lưu trữ — gom về một chỗ để không trùng.
abstract final class StorageKeys {
  // SharedPreferences
  static const themeMode = 'theme_mode';
  static const languageCode = 'language_code';
  static const currentUser = 'current_user';

  /// Chế độ chọn lần trước — mở app lên là sẵn chế độ quen dùng.
  static const lastActivityMode = 'last_activity_mode';

  /// Kiểu bản đồ đang chọn (đường / vệ tinh / ngoài trời / tối).
  static const mapStyle = 'map_style';

  /// Cân nặng để ước lượng calo.
  static const weightKg = 'weight_kg';

  /// Kiểu nền thẻ chia sẻ dùng lần trước.
  static const shareCardStyle = 'share_card_style';

  /// Công tắc "tính lại theo auto-pause" ở màn chi tiết hoạt động.
  static const autoPauseView = 'auto_pause_view';

  /// Cách báo mỗi khi xong một chặng: tắt / rung / giọng nói.
  static const splitAlertMode = 'split_alert_mode';

  /// Mốc thời gian (ISO) của điểm GPS cuối đã ghi xuống DB.
  ///
  /// Dùng để lọc nhật ký điểm mà foreground service ghi lúc app đã tắt: chỉ
  /// nhặt những điểm MỚI HƠN mốc này, không thì khôi phục xong là trùng điểm.
  static const lastPersistedFixAt = 'last_persisted_fix_at';

  // FlutterSecureStorage
  static const accessToken = 'access_token';
}
