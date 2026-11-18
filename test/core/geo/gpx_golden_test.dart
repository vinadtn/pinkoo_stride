import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/geo/gpx.dart';
import 'package:pinkoo_stride/core/geo/haversine.dart';
import 'package:pinkoo_stride/core/geo/route_splits.dart';
import 'package:pinkoo_stride/core/geo/simplify_route.dart';

/// Mốc đối chiếu là `assets/data/Afternoon_Swim.gpx` — chính file GPX mà
/// prototype HTML đã dùng để sinh mọi con số trên giao diện. Các giá trị kỳ
/// vọng dưới đây lấy từ `pinkoo-stride/README.md` của prototype, nên nếu phần
/// tính toán của app trôi đi là test đổ ngay.
void main() {
  late GpxTrack track;

  setUpAll(() {
    track = Gpx.decode(File('assets/data/Afternoon_Swim.gpx').readAsStringSync());
  });

  group('Gpx.decode trên file thật', () {
    test('đọc đúng tên, loại và số điểm', () {
      expect(track.name, 'Afternoon Swim');
      expect(track.type, 'swimming');
      expect(track.points.length, 3812);
    });

    test('quãng đường haversine ra 2.125,8 m như prototype', () {
      expect(track.distanceM, closeTo(2125.8, 0.1));
    });

    test('thời gian 1:03:46', () {
      expect(track.elapsedSec, 3826);
      expect(Duration(seconds: track.elapsedSec.round()).toString(), startsWith('1:03:46'));
    });

    test('toạ độ nằm trong vùng bãi Mỹ Khê', () {
      for (final p in track.points) {
        expect(p.lat, inInclusiveRange(16.0731, 16.0796));
        expect(p.lon, inInclusiveRange(108.2469, 108.2486));
      }
    });
  });

  group('simplifyRoute', () {
    test('sai số 0,6 m rút 3.812 điểm còn 475 điểm, đúng như prototype', () {
      expect(simplifyRoute(track.points, toleranceM: 0.6).length, 475);
    });

    test('luôn giữ điểm đầu và điểm cuối', () {
      final simplified = simplifyRoute(track.points, toleranceM: 5);
      expect(simplified.first, same(track.points.first));
      expect(simplified.last, same(track.points.last));
    });

    test('sai số càng lớn càng ít điểm, nhưng không bao giờ dưới 2', () {
      var previous = track.points.length;
      for (final tol in [0.6, 1.0, 2.0, 10.0, 100.0]) {
        final n = simplifyRoute(track.points, toleranceM: tol).length;
        expect(n, lessThanOrEqualTo(previous));
        expect(n, greaterThanOrEqualTo(2));
        previous = n;
      }
    });

    test('đường rút gọn NGẮN hơn đường gốc — nên thống kê phải dùng điểm gốc', () {
      // Douglas–Peucker cắt bỏ zigzag do GPS rung, nên polyline ngắn đi thật
      // (ở đây 2.125,8 m → ~1.861 m, lệch 12%). Đây chính là lý do prototype
      // tính mọi con số trên 3.812 điểm gốc và chỉ vẽ bằng 475 điểm đã rút.
      // Nếu một ngày nào đó quãng đường bị tính trên điểm đã rút, test này
      // không bắt được — nhưng test "quãng đường ra 2.125,8 m" ở trên thì bắt.
      final simplified = simplifyRoute(track.points, toleranceM: 0.6);
      final simplifiedLength = routeLengthMeters(simplified);
      expect(simplifiedLength, lessThan(track.distanceM));
      expect(simplifiedLength, greaterThan(track.distanceM * 0.8));
    });
  });

  group('computeSplits theo chặng 100 m', () {
    late List<RouteSplit> splits;

    setUpAll(() {
      final cum = cumulativeMeters(track.points);
      final t0 = track.points.first.time!;
      splits = computeSplits(
        [
          for (var i = 0; i < track.points.length; i++)
            _Timed(track.points[i].time!.difference(t0).inMilliseconds / 1000, cum[i]),
        ],
        splitDistanceM: 100,
      );
    });

    test('ra 21 chặng tròn + 1 chặng lẻ ~26 m', () {
      expect(splits.where((s) => !s.isPartial).length, 21);
      expect(splits.last.isPartial, isTrue);
      expect(splits.last.distanceM, closeTo(25.8, 0.1));
      // Prototype ghi "+ 26 m cuối trong 26 giây"; nội suy mốc chặng lệch ~1 s.
      expect(splits.last.durationSec, closeTo(26, 1.5));
    });

    test('tổng thời gian các chặng bằng tổng thời gian buổi tập', () {
      final sum = splits.fold<double>(0, (a, s) => a + s.durationSec);
      expect(sum, closeTo(track.elapsedSec, 0.01));
    });

    test('tổng quãng đường các chặng bằng quãng đường buổi tập', () {
      final sum = splits.fold<double>(0, (a, s) => a + s.distanceM);
      expect(sum, closeTo(track.distanceM, 0.01));
    });

    test('chặng nhanh nhất là chặng đầu, khoảng 1:52', () {
      final best = fastestSplitIndex(splits);
      expect(splits[best].index, 1);
      expect(splits[best].durationSec, closeTo(112, 1.5));
    });

    test('chặng lẻ không bao giờ bị chọn là nhanh nhất', () {
      // Chặng lẻ 25,8 m trong 27 s luôn "nhanh" hơn chặng 100 m nếu so bằng
      // thời gian thuần — bỏ sót chuyện này là lỗi hay gặp.
      final best = fastestSplitIndex(splits);
      expect(splits[best].isPartial, isFalse);
    });

    test('chặng 1 km trên cùng dữ liệu ra 2 chặng + phần lẻ', () {
      final cum = cumulativeMeters(track.points);
      final t0 = track.points.first.time!;
      final kmSplits = computeSplits(
        [
          for (var i = 0; i < track.points.length; i++)
            _Timed(track.points[i].time!.difference(t0).inMilliseconds / 1000, cum[i]),
        ],
        splitDistanceM: 1000,
      );
      expect(kmSplits.where((s) => !s.isPartial).length, 2);
      expect(kmSplits.last.distanceM, closeTo(125.8, 0.1));
    });

    test('ít hơn 2 điểm thì không có chặng nào', () {
      expect(computeSplits(const [_Timed(0, 0)], splitDistanceM: 100), isEmpty);
      expect(computeSplits([], splitDistanceM: 100), isEmpty);
    });
  });

  group('Gpx.encode', () {
    test('ghi rồi đọc lại giữ nguyên toạ độ và mốc thời gian', () {
      final startedAt = DateTime.utc(2026, 10, 4, 8, 25);
      final source = track.points.take(200).toList();
      final t0 = source.first.time!;

      final xml = Gpx.encode(
        trackName: 'Afternoon Swim',
        startedAt: startedAt,
        trackType: 'swimming',
        points: [
          for (final p in source)
            (
              lat: p.lat,
              lon: p.lon,
              tSec: p.time!.difference(t0).inMilliseconds / 1000,
              elevationM: p.elevationM,
            ),
        ],
      );

      final reread = Gpx.decode(xml);
      expect(reread.name, 'Afternoon Swim');
      expect(reread.type, 'swimming');
      expect(reread.points.length, source.length);
      expect(reread.points.first.time, startedAt);

      // 7 chữ số thập phân ≈ 1 cm, nên quãng đường gần như không đổi.
      expect(
        routeLengthMeters(reread.points),
        closeTo(routeLengthMeters(source), 0.05),
      );
      expect(reread.points.last.lat, closeTo(source.last.lat, 1e-7));
      expect(reread.points.last.lon, closeTo(source.last.lon, 1e-7));
    });

    test('là XML hợp lệ, có namespace GPX 1.1 và creator của app', () {
      final xml = Gpx.encode(
        trackName: 'Test',
        startedAt: DateTime.utc(2026, 1, 1),
        points: [(lat: 16.0, lon: 108.0, tSec: 0, elevationM: 3.0)],
      );
      expect(xml, contains('http://www.topografix.com/GPX/1/1'));
      expect(xml, contains('creator="Pinkoo Stride"'));
      expect(xml, contains('<ele>3.0</ele>'));
      expect(() => Gpx.decode(xml), returnsNormally);
    });

    test('tên có ký tự đặc biệt vẫn escape đúng', () {
      final xml = Gpx.encode(
        trackName: 'Chạy & <bơi> "sáng"',
        startedAt: DateTime.utc(2026, 1, 1),
        points: [(lat: 16.0, lon: 108.0, tSec: 0, elevationM: null)],
      );
      expect(Gpx.decode(xml).name, 'Chạy & <bơi> "sáng"');
    });

    test('file không có trkpt thì báo lỗi rõ ràng', () {
      expect(
        () => Gpx.decode('<gpx version="1.1"><trk><name>rỗng</name></trk></gpx>'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _Timed implements TimedPoint {
  const _Timed(this.tSec, this.cumulativeM);

  @override
  final double tSec;

  @override
  final double cumulativeM;
}
