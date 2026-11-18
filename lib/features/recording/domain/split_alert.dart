import '../../activity_mode/domain/activity_mode.dart';

/// Cách báo khi xong một chặng.
enum SplitAlertMode {
  /// Không báo gì — mặc định.
  off('off'),

  /// Rung theo mẫu. Nghe được cả khi máy trong túi, dưới nước vẫn cảm nhận được.
  haptic('haptic'),

  /// Đọc thành tiếng. Hợp khi chạy có tai nghe; bơi thì gần như vô dụng.
  voice('voice');

  const SplitAlertMode(this.id);

  /// Khoá lưu xuống SharedPreferences — dùng chuỗi để thêm kiểu mới sau này
  /// không làm sai cài đặt đã lưu.
  final String id;

  static SplitAlertMode fromId(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => SplitAlertMode.off);
}

/// Một chặng vừa hoàn thành.
class SplitAlert {
  const SplitAlert({
    required this.index,
    required this.mode,
    required this.distanceM,
    required this.paceSecPerUnit,
  });

  /// Chặng thứ mấy, đếm từ 1.
  final int index;

  final ActivityMode mode;

  /// Tổng quãng đường tại thời điểm báo.
  final double distanceM;

  /// Giây trên mỗi đơn vị của chế độ (km, hoặc 100 m với bơi).
  final double paceSecPerUnit;
}

/// Nơi phát tín hiệu báo chặng. Tách thành interface để `RecordingCubit` test
/// được mà không cần rung thật hay bộ đọc giọng nói.
abstract interface class SplitAnnouncer {
  Future<void> announce(SplitAlert alert);
}

/// Không báo gì — dùng khi người dùng tắt, và trong test.
class SilentSplitAnnouncer implements SplitAnnouncer {
  const SilentSplitAnnouncer();

  @override
  Future<void> announce(SplitAlert alert) async {}
}
