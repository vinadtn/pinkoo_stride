import '../../../core/geo/auto_pause.dart';
import '../../../core/geo/route_splits.dart' show TimedPoint;

/// Cách hiển thị "nhanh/chậm" của một chế độ.
enum PaceUnit {
  /// Phút:giây cho mỗi km — Chạy, Đi bộ.
  perKm,

  /// Phút:giây cho mỗi 100 m — Bơi (prototype hiển thị `3:00 /100m`).
  per100m,

  /// km/h — Đạp xe, vì pace /km ở tốc độ xe đạp đọc không có ý nghĩa.
  speedKmh,
}

/// Bốn chế độ vận động cơ bản.
///
/// Mọi thứ khác nhau giữa các chế độ gom hết vào đây — thêm chế độ mới chỉ cần
/// thêm một hằng số, không phải đi sửa rải rác trong UI và tầng tính toán.
///
/// Nhãn, icon và màu KHÔNG nằm ở đây (đó là việc của tầng presentation):
/// xem `features/activity_mode/presentation/activity_mode_ui.dart`.
enum ActivityMode {
  run(
    id: 'run',
    paceUnit: PaceUnit.perKm,
    splitDistanceM: 1000,
    met: 9.8,
    maxAccuracyM: 20,
    maxSpeedMps: 6.95, // 25 km/h — nhanh hơn thế là GPS nhảy, không phải người chạy
    minMovingSpeedMps: 0.5,
    gpsDistanceFilterM: 5,
    autoPauseEnterSec: 10,
    autoPauseExitSec: 3,
  ),
  walk(
    id: 'walk',
    paceUnit: PaceUnit.perKm,
    splitDistanceM: 1000,
    met: 3.5,
    maxAccuracyM: 20,
    maxSpeedMps: 3.34, // 12 km/h
    minMovingSpeedMps: 0.4,
    gpsDistanceFilterM: 5,
    autoPauseEnterSec: 10,
    autoPauseExitSec: 3,
  ),
  swim(
    id: 'swim',
    paceUnit: PaceUnit.per100m,
    splitDistanceM: 100,
    met: 8,
    // Bơi biển: máy nằm trong túi chống nước / trên tay ngập nước nên sai số
    // lớn hơn hẳn. Siết 20 m như chạy thì mất gần hết điểm.
    maxAccuracyM: 30,
    maxSpeedMps: 2.78, // 10 km/h
    // Bơi thì gần như không bao giờ "đứng yên": nước đẩy người trôi liên tục.
    // 0,05 m/s là mức tái hiện đúng "di chuyển 1:03:14" của buổi bơi mẫu.
    minMovingSpeedMps: 0.05,
    gpsDistanceFilterM: 3,
    autoPauseEnterSec: 20,
    autoPauseExitSec: 3,
  ),
  ride(
    id: 'ride',
    paceUnit: PaceUnit.speedKmh,
    splitDistanceM: 1000,
    met: 7.5,
    maxAccuracyM: 20,
    maxSpeedMps: 22.3, // 80 km/h
    minMovingSpeedMps: 0.8,
    gpsDistanceFilterM: 10,
    autoPauseEnterSec: 15,
    autoPauseExitSec: 3,
  );

  const ActivityMode({
    required this.id,
    required this.paceUnit,
    required this.splitDistanceM,
    required this.met,
    required this.maxAccuracyM,
    required this.maxSpeedMps,
    required this.minMovingSpeedMps,
    required this.gpsDistanceFilterM,
    required this.autoPauseEnterSec,
    required this.autoPauseExitSec,
  });

  /// Khoá lưu xuống DB và file GPX. Dùng string chứ không dùng `index` để
  /// chèn thêm chế độ sau này không làm sai dữ liệu đã lưu.
  final String id;

  final PaceUnit paceUnit;

  /// Độ dài một chặng trong biểu đồ split.
  final int splitDistanceM;

  /// MET — dùng tính calo: `kcal = MET × cân nặng(kg) × giờ`.
  final double met;

  /// Điểm GPS có sai số lớn hơn mức này bị bỏ.
  final double maxAccuracyM;

  /// Tốc độ tối đa còn coi là hợp lệ (m/s). Vượt ngưỡng = GPS nhảy → bỏ điểm.
  final double maxSpeedMps;

  /// Dưới tốc độ này coi như đang đứng yên → không cộng vào "thời gian di chuyển".
  final double minMovingSpeedMps;

  /// `distanceFilter` của geolocator: đi đủ số mét này mới nhận điểm mới.
  final int gpsDistanceFilterM;

  /// Phải chậm hơn [minMovingSpeedMps] liên tục bấy nhiêu giây thì mới coi là
  /// đang dừng. Bơi để cao hơn hẳn: nước đẩy người trôi nên tốc độ dao động
  /// quanh ngưỡng liên tục, lấy mốc ngắn là báo dừng oan.
  final int autoPauseEnterSec;

  /// Và phải nhanh trở lại liên tục bấy nhiêu giây mới coi là đi tiếp. Hai mốc
  /// tách rời như vậy thì một điểm GPS nhiễu không bật tắt trạng thái loạn xạ.
  final int autoPauseExitSec;

  /// Dưới ngưỡng này thì không đáng lưu thành một hoạt động.
  static const int minDistanceToSaveM = 50;

  static ActivityMode fromId(String id) =>
      values.firstWhere((m) => m.id == id, orElse: () => ActivityMode.run);

  /// Chặng tính theo 100 m thay vì km — chỉ Bơi.
  bool get splitsIn100m => splitDistanceM == 100;

  /// Hiển thị tốc độ (km/h) thay vì pace (phút/km).
  bool get showsSpeed => paceUnit == PaceUnit.speedKmh;

  /// Bộ theo dõi auto-pause mang sẵn ngưỡng của chế độ này.
  AutoPauseWatcher autoPauseWatcher() => AutoPauseWatcher(
    minMovingSpeedMps: minMovingSpeedMps,
    enterSec: autoPauseEnterSec,
    exitSec: autoPauseExitSec,
  );

  /// Các khoảng đứng yên trong một track đã ghi xong, theo ngưỡng của chế độ này.
  List<PausedInterval> detectPausesIn(List<TimedPoint> points) => detectPauses(
    points,
    minMovingSpeedMps: minMovingSpeedMps,
    enterSec: autoPauseEnterSec,
    exitSec: autoPauseExitSec,
  );
}
