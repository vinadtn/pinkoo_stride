import 'route_splits.dart' show TimedPoint;

/// Một khoảng thời gian bị coi là đang dừng, tính theo `tSec` của track.
class PausedInterval {
  const PausedInterval({required this.fromSec, required this.toSec});

  final double fromSec;
  final double toSec;

  double get durationSec => toSec - fromSec;

  @override
  String toString() =>
      'PausedInterval(${fromSec.toStringAsFixed(0)}s → ${toSec.toStringAsFixed(0)}s)';

  @override
  bool operator ==(Object other) =>
      other is PausedInterval && other.fromSec == fromSec && other.toSec == toSec;

  @override
  int get hashCode => Object.hash(fromSec, toSec);
}

/// Theo dõi các khoảng người dùng đứng yên, nạp từng điểm một.
///
/// **Chỉ quan sát, không can thiệp.** Lớp này không đổi điểm GPS, không đổi
/// quãng đường, không dừng buổi ghi. Nó phục vụ hai chỗ:
/// - lúc đang ghi: ghi log để thấy thuật toán nhận định thế nào;
/// - ở màn lịch sử: tính lại thời gian "nếu có auto-pause" để người dùng so sánh.
///
/// Vì chỉ cần `tSec` và `cumulativeM` — hai thứ đã lưu sẵn trong `track_points` —
/// nên **mọi buổi đã ghi từ trước đều tính lại được**, không cần thêm cột nào.
///
/// Dùng HAI mốc thời gian tách rời ([enterSec] để vào trạng thái dừng,
/// [exitSec] để thoát ra) thay vì so tốc độ từng điểm: lúc đứng yên GPS vẫn trôi
/// quanh vài mét, so từng điểm thì trạng thái bật tắt liên tục và ra hàng chục
/// khoảng dừng dài một giây.
///
/// Lúc ghi và lúc xem lại dùng CHUNG lớp này, nên hai bên không thể ra kết quả
/// khác nhau.
class AutoPauseWatcher {
  AutoPauseWatcher({
    required this.minMovingSpeedMps,
    required this.enterSec,
    required this.exitSec,
  });

  /// Chậm hơn mức này (m/s) thì đoạn đó coi như đứng yên.
  final double minMovingSpeedMps;

  /// Phải chậm liên tục bấy nhiêu giây mới coi là đã dừng.
  final int enterSec;

  /// Và phải nhanh trở lại liên tục bấy nhiêu giây mới coi là đi tiếp.
  final int exitSec;

  final List<PausedInterval> _closed = [];

  TimedPoint? _prev;
  bool _stopped = false;

  /// Khi đang đi: gom các đoạn chậm liên tiếp, đủ dài thì chuyển sang "dừng".
  double? _slowRunStart;
  double _slowRunSec = 0;

  /// Khi đang dừng: gom các đoạn nhanh liên tiếp, đủ dài thì chuyển về "đi".
  double _fastRunSec = 0;

  double _stopStart = 0;
  double _stopEnd = 0;

  /// Đang trong một khoảng bị coi là dừng.
  bool get isStopped => _stopped;

  /// Khoảng dừng đang mở, hoặc null khi đang di chuyển.
  PausedInterval? get openInterval =>
      _stopped ? PausedInterval(fromSec: _stopStart, toSec: _stopEnd) : null;

  /// Nạp điểm tiếp theo. Trả về khoảng dừng vừa KẾT THÚC ở điểm này, hoặc null.
  PausedInterval? add(TimedPoint point) {
    final prev = _prev;
    _prev = point;
    if (prev == null) return null;

    final dt = point.tSec - prev.tSec;
    // Mốc thời gian không tiến lên thì không suy ra được tốc độ — bỏ qua đoạn.
    if (dt <= 0) return null;

    final speed = (point.cumulativeM - prev.cumulativeM) / dt;
    final slow = speed < minMovingSpeedMps;

    if (!_stopped) {
      if (slow) {
        _slowRunStart ??= prev.tSec;
        _slowRunSec += dt;
        if (_slowRunSec >= enterSec) {
          _stopped = true;
          _stopStart = _slowRunStart!;
          _stopEnd = point.tSec;
          _fastRunSec = 0;
          _slowRunStart = null;
          _slowRunSec = 0;
        }
      } else {
        _slowRunStart = null;
        _slowRunSec = 0;
      }
      return null;
    }

    if (slow) {
      // Một nhịp nhanh ngắn giữa lúc đang dừng chỉ là nhiễu — nuốt luôn.
      _fastRunSec = 0;
      _stopEnd = point.tSec;
      return null;
    }

    _fastRunSec += dt;
    if (_fastRunSec < exitSec) return null;

    final closed = PausedInterval(fromSec: _stopStart, toSec: _stopEnd);
    _closed.add(closed);
    _stopped = false;
    _fastRunSec = 0;
    return closed;
  }

  /// Chốt sổ — gộp cả khoảng đang mở (track kết thúc lúc vẫn đang đứng yên).
  List<PausedInterval> finish() => [..._closed, ?openInterval];
}

/// Tìm các khoảng đứng yên trong một track đã ghi xong.
List<PausedInterval> detectPauses(
  List<TimedPoint> points, {
  required double minMovingSpeedMps,
  required int enterSec,
  required int exitSec,
}) {
  final watcher = AutoPauseWatcher(
    minMovingSpeedMps: minMovingSpeedMps,
    enterSec: enterSec,
    exitSec: exitSec,
  );
  for (final point in points) {
    watcher.add(point);
  }
  return watcher.finish();
}

/// Tổng thời gian bị coi là dừng, tính bằng giây.
double pausedSeconds(Iterable<PausedInterval> intervals) =>
    intervals.fold(0, (sum, i) => sum + i.durationSec);
