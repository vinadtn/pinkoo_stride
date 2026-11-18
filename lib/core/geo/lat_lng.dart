/// Thứ gì có toạ độ thì dùng được mọi hàm trong `core/geo`.
///
/// Nhờ interface này mà `haversineMeters` / `simplifyRoute` chạy được cả trên
/// `GeoPoint` (toạ độ trần) lẫn `TrackPoint` (có thêm thời gian, sai số...)
/// mà không phải chuyển đổi qua lại.
abstract interface class LatLng {
  double get lat;
  double get lon;
}

/// Toạ độ trần, không kèm gì khác.
class GeoPoint implements LatLng {
  const GeoPoint(this.lat, this.lon);

  @override
  final double lat;

  @override
  final double lon;

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}
