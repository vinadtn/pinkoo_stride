import '../../../core/geo/lat_lng.dart';

/// Một lần định vị thô, chưa lọc gì — đúng những gì thiết bị (hoặc nguồn phát
/// lại khi test) đưa ra.
class RawFix implements LatLng {
  const RawFix({
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.accuracyM,
    this.elevationM,
    this.speedMps,
  });

  @override
  final double lat;

  @override
  final double lon;

  /// Mốc thời gian của chính lần định vị đó, KHÔNG phải lúc app nhận được —
  /// dùng giờ máy nhận thì mọi phép tính tốc độ lệch khi hệ thống giữ gói lại.
  final DateTime timestamp;

  /// Sai số ngang, mét. null = thiết bị không báo.
  final double? accuracyM;

  final double? elevationM;

  /// Tốc độ thiết bị tự báo (m/s) — chỉ để tham khảo; tốc độ dùng để lọc được
  /// tính lại từ khoảng cách giữa hai điểm.
  final double? speedMps;

  @override
  String toString() => 'RawFix($lat, $lon, acc=$accuracyM, $timestamp)';
}
