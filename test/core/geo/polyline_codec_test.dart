import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/geo/gpx.dart';
import 'package:pinkoo_stride/core/geo/lat_lng.dart';
import 'package:pinkoo_stride/core/geo/polyline_codec.dart';
import 'package:pinkoo_stride/core/geo/simplify_route.dart';

void main() {
  test('khớp ví dụ chuẩn của thuật toán Encoded Polyline', () {
    // Ví dụ trong tài liệu Google: 3 điểm → `_p~iF~ps|U_ulLnnqC_mqNvxq`@`.
    const points = [
      GeoPoint(38.5, -120.2),
      GeoPoint(40.7, -120.95),
      GeoPoint(43.252, -126.453),
    ];
    expect(PolylineCodec.encode(points), r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  });

  test('encode rồi decode trả lại toạ độ trong sai số 1e-5', () {
    final track = Gpx.decode(File('assets/data/Afternoon_Swim.gpx').readAsStringSync());
    final thinned = simplifyRoute(track.points, toleranceM: 5);

    final decoded = PolylineCodec.decode(PolylineCodec.encode(thinned));
    expect(decoded.length, thinned.length);
    for (var i = 0; i < decoded.length; i++) {
      expect(decoded[i].lat, closeTo(thinned[i].lat, 1e-5));
      expect(decoded[i].lon, closeTo(thinned[i].lon, 1e-5));
    }
  });

  test('ngắn hơn hẳn so với viết toạ độ dạng chữ — đủ nhét vào URL', () {
    final track = Gpx.decode(File('assets/data/Afternoon_Swim.gpx').readAsStringSync());
    final thinned = simplifyRoute(track.points, toleranceM: 5);

    final encoded = PolylineCodec.encode(thinned);
    final plain = thinned.map((p) => '${p.lon},${p.lat}').join(';');
    expect(encoded.length, lessThan(plain.length ~/ 2));
  });

  test('danh sách rỗng ra chuỗi rỗng', () {
    expect(PolylineCodec.encode(const []), '');
    expect(PolylineCodec.decode(''), isEmpty);
  });
}
