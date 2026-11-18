import 'dart:math' as math;

import 'lat_lng.dart';

/// Bán kính trung bình Trái Đất (IUGG mean radius) — cùng hằng số prototype dùng
/// để ra con số 2.125,8 m cho file `Afternoon_Swim.gpx`.
const double earthRadiusM = 6371008.8;

/// Khoảng cách giữa hai toạ độ theo công thức haversine, đơn vị mét.
///
/// Haversine coi Trái Đất là hình cầu nên sai khoảng 0,3% so với ellipsoid —
/// với quãng vài chục mét giữa hai điểm GPS thì sai số đó nhỏ hơn hẳn sai số
/// của chính thiết bị, nên không cần Vincenty cho nặng.
double haversineMeters(LatLng a, LatLng b) {
  final lat1 = a.lat * math.pi / 180;
  final lat2 = b.lat * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLon = (b.lon - a.lon) * math.pi / 180;

  final sinDLat = math.sin(dLat / 2);
  final sinDLon = math.sin(dLon / 2);
  final h = sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLon * sinDLon;

  return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Tổng chiều dài một chuỗi điểm (cộng dồn từng đoạn liền kề).
double routeLengthMeters(List<LatLng> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return total;
}

/// Quãng đường cộng dồn tới từng điểm — phần tử đầu luôn là 0.
///
/// Dùng để tua lại theo quãng đường (thanh scrub ở màn chi tiết) và để chia
/// chặng mà không phải tính lại haversine mỗi lần.
List<double> cumulativeMeters(List<LatLng> points) {
  final out = List<double>.filled(points.length, 0);
  for (var i = 1; i < points.length; i++) {
    out[i] = out[i - 1] + haversineMeters(points[i - 1], points[i]);
  }
  return out;
}
