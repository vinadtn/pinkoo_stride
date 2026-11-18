import 'lat_lng.dart';

/// Mã hoá chuỗi toạ độ theo thuật toán Encoded Polyline (precision 5).
///
/// Cần cho Mapbox Static Images API: nhúng đường đi vào URL dưới dạng
/// `path-5+ce3f6c(<encoded>)`. Toạ độ dạng chữ thường dài gấp nhiều lần, rất
/// nhanh vượt giới hạn độ dài URL.
abstract final class PolylineCodec {
  /// Nhân với 1e5 — precision 5, sai số ~1 m, đủ cho ảnh bản đồ tĩnh.
  static const _factor = 1e5;

  static String encode(List<LatLng> points) {
    final out = StringBuffer();
    var prevLat = 0;
    var prevLon = 0;

    for (final p in points) {
      final lat = (p.lat * _factor).round();
      final lon = (p.lon * _factor).round();
      // Mã hoá hiệu so với điểm trước, nên đường đi liền mạch rất ngắn gọn.
      _writeValue(out, lat - prevLat);
      _writeValue(out, lon - prevLon);
      prevLat = lat;
      prevLon = lon;
    }
    return out.toString();
  }

  static void _writeValue(StringBuffer out, int value) {
    // Zigzag: số âm thành số dương chẵn/lẻ xen kẽ.
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  /// Giải mã — dùng trong test để kiểm tra encode đúng.
  static List<GeoPoint> decode(String encoded) {
    final points = <GeoPoint>[];
    var index = 0;
    var lat = 0;
    var lon = 0;

    while (index < encoded.length) {
      final (dLat, next1) = _readValue(encoded, index);
      lat += dLat;
      final (dLon, next2) = _readValue(encoded, next1);
      lon += dLon;
      index = next2;
      points.add(GeoPoint(lat / _factor, lon / _factor));
    }
    return points;
  }

  static (int, int) _readValue(String encoded, int start) {
    var shift = 0;
    var result = 0;
    var index = start;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return (value, index);
  }
}
