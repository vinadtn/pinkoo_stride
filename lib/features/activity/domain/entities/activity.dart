import '../../../activity_mode/domain/activity_mode.dart';
import 'track_point.dart';

/// Một buổi vận động đã ghi xong.
///
/// Mọi con số đều tính từ điểm GPS thật và lưu lại khi dừng, để màn danh sách
/// không phải đọc hàng nghìn track point chỉ để hiện một thẻ.
class Activity {
  const Activity({
    required this.id,
    required this.mode,
    required this.title,
    required this.startedAt,
    required this.elapsedSec,
    required this.movingSec,
    required this.distanceM,
    required this.pointCount,
    this.endedAt,
    this.calories,
    this.elevationGainM,
    this.placeLabel,
    this.note,
    this.points = const [],
  });

  final int id;
  final ActivityMode mode;

  /// Ví dụ "Buổi chạy chiều" — sinh tự động lúc lưu, người dùng sửa được.
  final String title;

  final DateTime startedAt;
  final DateTime? endedAt;

  /// Tổng thời gian từ lúc bấm Bắt đầu tới lúc Dừng, trừ thời gian tạm dừng.
  final int elapsedSec;

  /// Thời gian thực sự đang di chuyển (bỏ lúc đứng yên) — prototype gọi là
  /// "Thời gian di chuyển".
  final int movingSec;

  final double distanceM;

  /// Số điểm GPS gốc đã ghi (prototype hiển thị 3.812).
  final int pointCount;

  final double? calories;
  final double? elevationGainM;

  /// Nhãn vị trí, ví dụ "Bãi biển Mỹ Khê, Đà Nẵng". Chưa reverse-geocode thì null.
  final String? placeLabel;

  final String? note;

  /// Rỗng khi đọc danh sách; chỉ nạp đủ khi mở màn chi tiết.
  final List<TrackPoint> points;

  double get distanceKm => distanceM / 1000;

  /// Giây cho mỗi km. 0 khi chưa đi được gì.
  double get secPerKm => distanceM <= 0 ? 0 : elapsedSec / distanceKm;

  /// Giây cho mỗi 100 m — đơn vị của chế độ Bơi.
  double get secPer100m => distanceM <= 0 ? 0 : elapsedSec / (distanceM / 100);

  double get avgSpeedKmh => elapsedSec <= 0 ? 0 : distanceKm / (elapsedSec / 3600);

  Activity copyWith({String? title, String? note, List<TrackPoint>? points}) => Activity(
    id: id,
    mode: mode,
    title: title ?? this.title,
    startedAt: startedAt,
    endedAt: endedAt,
    elapsedSec: elapsedSec,
    movingSec: movingSec,
    distanceM: distanceM,
    pointCount: pointCount,
    calories: calories,
    elevationGainM: elevationGainM,
    placeLabel: placeLabel,
    note: note ?? this.note,
    points: points ?? this.points,
  );
}
