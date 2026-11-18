import '../../../core/geo/haversine.dart';
import '../../activity/domain/entities/track_point.dart';
import '../../activity_mode/domain/activity_mode.dart';
import 'raw_fix.dart';

/// Lý do một lần định vị bị bỏ — giữ lại để hiện chất lượng GPS trên UI và để
/// debug những buổi ghi ra số liệu vô lý.
enum FixRejection {
  /// Sai số thiết bị báo lớn hơn ngưỡng của chế độ.
  poorAccuracy,

  /// Mốc thời gian không tiến lên (trùng điểm, hoặc gói về không đúng thứ tự).
  notMovingForward,

  /// Khoảng cách / thời gian cho ra tốc độ phi lý → GPS nhảy.
  impossibleJump,

  /// Đang tạm dừng.
  paused,
}

/// Biến chuỗi [RawFix] thành track đã lọc, đồng thời cộng dồn quãng đường,
/// thời gian và thời gian di chuyển.
///
/// Thuần Dart, không phụ thuộc plugin nào — nên test được toàn bộ logic lọc
/// bằng cách phát lại một file GPX thật, không cần ra đường chạy.
///
/// `tSec` của mỗi điểm là **thời gian đã trừ các khoảng tạm dừng**, nên tua lại
/// ở màn chi tiết không bị đứng im ở đoạn người dùng dừng nghỉ.
class TrackAccumulator {
  /// [startedAt] là lúc người dùng bấm Bắt đầu.
  ///
  /// Phải truyền vào, đừng để đồng hồ bắt đầu từ điểm GPS đầu tiên: trong nhà
  /// hoặc dưới tán cây, GPS có thể mất vài chục giây mới bắt được sóng, và suốt
  /// khoảng đó màn hình sẽ đứng ở 0:00:00 làm người dùng tưởng app treo.
  // Không dùng được `this._startedAt`: tham số đặt tên không được bắt đầu bằng
  // dấu gạch dưới, nên ở đây buộc phải gán trong initializer list.
  // ignore: prefer_initializing_formals
  TrackAccumulator({required this.mode, DateTime? startedAt}) : _startedAt = startedAt;

  final ActivityMode mode;

  final List<TrackPoint> _points = [];
  DateTime? _startedAt;
  DateTime? _lastFixAt;
  DateTime? _pausedAt;
  Duration _pausedTotal = Duration.zero;

  double _distanceM = 0;
  double _movingSec = 0;
  double _elevationGainM = 0;
  double? _lastElevationM;
  final Map<FixRejection, int> _rejections = {};

  List<TrackPoint> get points => List.unmodifiable(_points);

  DateTime? get startedAt => _startedAt;

  double get distanceM => _distanceM;

  /// Thời gian ghi tới điểm GPS cuối cùng, đã trừ các khoảng tạm dừng.
  double get elapsedSec => _points.isEmpty ? 0 : _points.last.tSec;

  /// Thời gian ghi tính tới [now] — dùng cho đồng hồ trên màn hình, để nó vẫn
  /// chạy từng giây kể cả lúc GPS chưa trả điểm mới.
  double elapsedSecAt(DateTime now) {
    final startedAt = _startedAt;
    if (startedAt == null) return 0;
    final pausedMs =
        _pausedTotal.inMilliseconds +
        (_pausedAt == null ? 0 : now.difference(_pausedAt!).inMilliseconds);
    final ms = now.difference(startedAt).inMilliseconds - pausedMs;
    return ms <= 0 ? 0 : ms / 1000;
  }

  double get movingSec => _movingSec;

  double get elevationGainM => _elevationGainM;

  bool get isPaused => _pausedAt != null;

  int get pointCount => _points.length;

  Map<FixRejection, int> get rejections => Map.unmodifiable(_rejections);

  /// Tốc độ hiện tại (m/s), tính từ hai điểm cuối. null khi chưa đủ dữ liệu.
  double? get currentSpeedMps {
    if (_points.length < 2) return null;
    final a = _points[_points.length - 2];
    final b = _points.last;
    final dt = b.tSec - a.tSec;
    if (dt <= 0) return null;
    return (b.cumulativeM - a.cumulativeM) / dt;
  }

  void pause(DateTime at) {
    if (_pausedAt != null) return;
    _pausedAt = at;
  }

  void resume(DateTime at) {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    _pausedTotal += at.difference(pausedAt);
    _pausedAt = null;
    // Điểm đầu sau khi tiếp tục không được nối thẳng với điểm trước lúc dừng:
    // người dùng có thể đã đi chỗ khác. Quên điểm cuối đi để đoạn đó không bị
    // cộng vào quãng đường.
    _lastFixAt = null;
  }

  /// Nạp một lần định vị. Trả về `null` nếu nhận, hoặc lý do bị bỏ.
  FixRejection? add(RawFix fix) {
    if (_pausedAt != null) return _reject(FixRejection.paused);

    final accuracy = fix.accuracyM;
    if (accuracy != null && accuracy > mode.maxAccuracyM) {
      return _reject(FixRejection.poorAccuracy);
    }

    _startedAt ??= fix.timestamp;
    final tSec = fix.timestamp.difference(_startedAt!).inMilliseconds / 1000 -
        _pausedTotal.inMilliseconds / 1000;

    // Điểm đầu tiên (hoặc điểm đầu sau khi tiếp tục): không có gì để so.
    final last = _points.isEmpty || _lastFixAt == null ? null : _points.last;
    if (last == null) {
      _accept(fix, tSec: tSec, cumulativeM: _distanceM);
      return null;
    }

    final dt = fix.timestamp.difference(_lastFixAt!).inMilliseconds / 1000;
    if (dt <= 0) return _reject(FixRejection.notMovingForward);

    final d = haversineMeters(last, fix);
    final speed = d / dt;
    if (speed > mode.maxSpeedMps) return _reject(FixRejection.impossibleJump);

    _distanceM += d;
    if (speed > mode.minMovingSpeedMps) _movingSec += dt;
    _accept(fix, tSec: tSec, cumulativeM: _distanceM);
    return null;
  }

  void _accept(RawFix fix, {required double tSec, required double cumulativeM}) {
    final ele = fix.elevationM;
    if (ele != null) {
      final prev = _lastElevationM;
      // Dưới 1 m là nhiễu của GPS, không phải leo dốc.
      if (prev != null && ele - prev > 1) _elevationGainM += ele - prev;
      if (prev == null || (ele - prev).abs() > 1) _lastElevationM = ele;
    }

    _points.add(
      TrackPoint(
        lat: fix.lat,
        lon: fix.lon,
        tSec: tSec,
        cumulativeM: cumulativeM,
        elevationM: fix.elevationM,
        accuracyM: fix.accuracyM,
        speedMps: fix.speedMps,
      ),
    );
    _lastFixAt = fix.timestamp;
  }

  FixRejection _reject(FixRejection reason) {
    _rejections.update(reason, (n) => n + 1, ifAbsent: () => 1);
    return reason;
  }

  /// Dựng lại trạng thái từ các điểm đã lưu — dùng khi phục hồi buổi ghi sau
  /// khi app bị kill giữa lúc đang ghi.
  ///
  /// [resumedAt] là thời điểm ghi tiếp (thường là `DateTime.now()`). Khoảng
  /// app chết được tính như một lần tạm dừng, nên đồng hồ tiếp tục từ đúng chỗ
  /// cũ thay vì nhảy thêm vài phút người dùng không hề vận động.
  void restore({
    required DateTime startedAt,
    required DateTime resumedAt,
    required List<TrackPoint> points,
    required double movingSec,
    double elevationGainM = 0,
  }) {
    _startedAt = startedAt;
    _points
      ..clear()
      ..addAll(points);
    _movingSec = movingSec;
    _elevationGainM = elevationGainM;
    _distanceM = points.isEmpty ? 0 : points.last.cumulativeM;
    _lastElevationM = points.isEmpty ? null : points.last.elevationM;
    // Chưa biết điểm cuối cách bây giờ bao lâu → coi như vừa tiếp tục, không
    // nối đoạn từ điểm cũ sang điểm mới.
    _lastFixAt = null;
    _pausedAt = null;

    final elapsedBefore = points.isEmpty ? 0.0 : points.last.tSec;
    final wallGapMs = resumedAt.difference(startedAt).inMilliseconds;
    _pausedTotal = Duration(
      milliseconds: (wallGapMs - elapsedBefore * 1000).round().clamp(0, wallGapMs),
    );
  }
}
