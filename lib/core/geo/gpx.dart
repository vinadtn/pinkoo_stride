import 'package:xml/xml.dart';

import 'haversine.dart';
import 'lat_lng.dart';

/// Một điểm đọc được từ file GPX: toạ độ + mốc thời gian tuyệt đối.
class GpxPoint implements LatLng {
  const GpxPoint({required this.lat, required this.lon, this.elevationM, this.time});

  @override
  final double lat;

  @override
  final double lon;

  final double? elevationM;
  final DateTime? time;
}

/// Nội dung một track trong file GPX.
class GpxTrack {
  const GpxTrack({required this.name, required this.points, this.type});

  final String? name;

  /// Giá trị thẻ `<type>` — Strava ghi "swimming", "running"...
  final String? type;

  final List<GpxPoint> points;

  DateTime? get startedAt => points.firstWhere((p) => p.time != null, orElse: () => points.first).time;

  /// Tổng quãng đường theo haversine trên TOÀN BỘ điểm (không rút gọn).
  double get distanceM => routeLengthMeters(points);

  /// Giây từ điểm đầu tới điểm cuối.
  double get elapsedSec {
    final first = points.first.time;
    final last = points.last.time;
    if (first == null || last == null) return 0;
    return last.difference(first).inMilliseconds / 1000;
  }
}

/// Đọc / ghi file GPX 1.1.
///
/// Ghi: để người dùng xuất buổi tập ra file mở được bằng Strava, Garmin Connect...
/// Đọc: dùng cho test (lấy `Afternoon_Swim.gpx` làm mốc đối chiếu) và để phát
/// lại track thật thành stream GPS giả khi kiểm thử trên máy.
abstract final class Gpx {
  static const _ns = 'http://www.topografix.com/GPX/1/1';
  static const creator = 'Pinkoo Stride';

  /// Sinh nội dung file GPX từ một chuỗi điểm.
  ///
  /// [startedAt] là mốc tuyệt đối của điểm đầu; mỗi điểm có `tSec` là số giây
  /// lệch so với mốc đó (đúng cách app lưu trong DB).
  static String encode({
    required String trackName,
    required DateTime startedAt,
    required List<({double lat, double lon, double tSec, double? elevationM})> points,
    String? trackType,
  }) {
    final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element(
      'gpx',
      nest: () {
        b
          ..attribute('version', '1.1')
          ..attribute('creator', creator)
          ..attribute('xmlns', _ns);

        b.element(
          'metadata',
          nest: () {
            b.element('name', nest: trackName);
            b.element('time', nest: _iso(startedAt));
          },
        );

        b.element(
          'trk',
          nest: () {
            b.element('name', nest: trackName);
            if (trackType != null) b.element('type', nest: trackType);
            b.element(
              'trkseg',
              nest: () {
                for (final p in points) {
                  b.element(
                    'trkpt',
                    nest: () {
                      b
                        ..attribute('lat', _coord(p.lat))
                        ..attribute('lon', _coord(p.lon));
                      if (p.elevationM != null) {
                        b.element('ele', nest: p.elevationM!.toStringAsFixed(1));
                      }
                      b.element(
                        'time',
                        nest: _iso(
                          startedAt.add(Duration(milliseconds: (p.tSec * 1000).round())),
                        ),
                      );
                    },
                  );
                }
              },
            );
          },
        );
      },
    );
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// Đọc track đầu tiên trong file GPX. Ném [FormatException] nếu không có điểm nào.
  static GpxTrack decode(String xml) {
    final doc = XmlDocument.parse(xml);

    // Bỏ qua namespace: file ngoài đời dùng gpx/1/0, gpx/1/1, có file còn
    // thêm tiền tố lạ — so theo tên cục bộ thì đọc được hết.
    Iterable<XmlElement> byName(XmlNode root, String name) =>
        root.descendantElements.where((e) => e.localName == name);

    final trk = byName(doc, 'trk').firstOrNull;
    final root = trk ?? doc.rootElement;

    final points = <GpxPoint>[];
    for (final e in byName(root, 'trkpt')) {
      final lat = double.tryParse(e.getAttribute('lat') ?? '');
      final lon = double.tryParse(e.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;
      points.add(
        GpxPoint(
          lat: lat,
          lon: lon,
          elevationM: double.tryParse(byName(e, 'ele').firstOrNull?.innerText ?? ''),
          time: DateTime.tryParse(byName(e, 'time').firstOrNull?.innerText ?? '')?.toUtc(),
        ),
      );
    }

    if (points.isEmpty) throw const FormatException('File GPX không có điểm <trkpt> nào');

    return GpxTrack(
      name: byName(root, 'name').firstOrNull?.innerText.trim(),
      type: byName(root, 'type').firstOrNull?.innerText.trim(),
      points: points,
    );
  }

  /// 7 chữ số thập phân ≈ 1 cm — đủ chính xác, mà không phình file.
  static String _coord(double v) => v.toStringAsFixed(7);

  static String _iso(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';
}
