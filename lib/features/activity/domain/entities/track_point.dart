import '../../../../core/geo/lat_lng.dart';
import '../../../../core/geo/route_splits.dart';

/// Một điểm GPS đã được lọc và cộng dồn quãng đường.
///
/// Implement cả [LatLng] và [TimedPoint] nên dùng trực tiếp được với
/// `haversineMeters`, `simplifyRoute`, `computeSplits` mà không cần chuyển đổi.
class TrackPoint implements LatLng, TimedPoint {
  const TrackPoint({
    required this.lat,
    required this.lon,
    required this.tSec,
    required this.cumulativeM,
    this.elevationM,
    this.accuracyM,
    this.speedMps,
  });

  @override
  final double lat;

  @override
  final double lon;

  /// Giây kể từ điểm đầu của hoạt động (không phải epoch) — nhẹ hơn lưu
  /// DateTime từng điểm, và tua lại chỉ cần số tương đối.
  @override
  final double tSec;

  @override
  final double cumulativeM;

  final double? elevationM;

  /// Sai số ngang do thiết bị báo, mét. Giữ lại để sau này biết đoạn nào đáng tin.
  final double? accuracyM;

  /// Tốc độ tức thời do thiết bị báo, m/s.
  final double? speedMps;

  TrackPoint copyWith({double? tSec, double? cumulativeM}) => TrackPoint(
    lat: lat,
    lon: lon,
    tSec: tSec ?? this.tSec,
    cumulativeM: cumulativeM ?? this.cumulativeM,
    elevationM: elevationM,
    accuracyM: accuracyM,
    speedMps: speedMps,
  );

  @override
  String toString() =>
      'TrackPoint($lat, $lon, t=${tSec}s, d=${cumulativeM.toStringAsFixed(1)}m)';
}
