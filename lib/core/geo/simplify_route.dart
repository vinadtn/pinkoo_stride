import 'dart:math' as math;

import 'haversine.dart';
import 'lat_lng.dart';

/// Rút gọn đường đi bằng Douglas–Peucker, sai số tính theo **mét**.
///
/// Dùng để VẼ cho mượt, không dùng để tính thống kê: prototype rút 3.812 điểm
/// còn 475 điểm với sai số 0,6 m, nhưng quãng đường / pace vẫn tính trên toàn
/// bộ điểm gốc. Giữ đúng nguyên tắc đó ở app — vẽ thì rút, tính thì không.
///
/// Trả về danh sách con của [points] (giữ nguyên object, nên `tSec` và mọi
/// thuộc tính khác đi theo), luôn gồm điểm đầu và điểm cuối.
List<T> simplifyRoute<T extends LatLng>(List<T> points, {double toleranceM = 1}) {
  if (points.length < 3 || toleranceM <= 0) return List<T>.of(points);

  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  // Đệ quy bằng stack để không tràn stack với track dài (có buổi đạp xe
  // vài chục nghìn điểm).
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (first, last) = stack.removeLast();
    if (last <= first + 1) continue;

    var maxDist = -1.0;
    var maxIndex = first;
    for (var i = first + 1; i < last; i++) {
      final d = _perpendicularDistanceM(points[i], points[first], points[last]);
      if (d > maxDist) {
        maxDist = d;
        maxIndex = i;
      }
    }

    if (maxDist > toleranceM) {
      keep[maxIndex] = true;
      stack
        ..add((first, maxIndex))
        ..add((maxIndex, last));
    }
  }

  final out = <T>[];
  for (var i = 0; i < points.length; i++) {
    if (keep[i]) out.add(points[i]);
  }
  return out;
}

/// Khoảng cách từ [p] tới đoạn thẳng [a]–[b], đơn vị mét.
///
/// Chiếu phẳng quanh [a] (equirectangular): ở quy mô vài trăm mét sai số của
/// phép chiếu này nhỏ hơn 1 mm, mà rẻ hơn hẳn so với tính trên mặt cầu.
double _perpendicularDistanceM(LatLng p, LatLng a, LatLng b) {
  final latRad = a.lat * math.pi / 180;
  const mPerDegLat = earthRadiusM * math.pi / 180;
  final mPerDegLon = mPerDegLat * math.cos(latRad);

  final px = (p.lon - a.lon) * mPerDegLon;
  final py = (p.lat - a.lat) * mPerDegLat;
  final bx = (b.lon - a.lon) * mPerDegLon;
  final by = (b.lat - a.lat) * mPerDegLat;

  final segLenSq = bx * bx + by * by;
  if (segLenSq == 0) return math.sqrt(px * px + py * py);

  // Hình chiếu của p lên đoạn, kẹp vào [0,1] để điểm ngoài đoạn tính tới đầu mút.
  var t = (px * bx + py * by) / segLenSq;
  t = t.clamp(0.0, 1.0);

  final dx = px - t * bx;
  final dy = py - t * by;
  return math.sqrt(dx * dx + dy * dy);
}
