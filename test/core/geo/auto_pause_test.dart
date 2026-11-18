import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/geo/gpx.dart';
import 'package:pinkoo_stride/core/geo/haversine.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/core/geo/auto_pause.dart';

/// Auto-pause chỉ QUAN SÁT. Bài test ở đây khoá hai thứ:
/// - nó tìm đúng khoảng đứng yên,
/// - và nó không hề đụng vào dữ liệu được truyền vào.
void main() {
  /// Dựng track thẳng: mỗi giây một điểm, tốc độ đặt theo từng chặng.
  ///
  /// `segments` là danh sách (số giây, tốc độ m/s).
  List<TrackPoint> buildTrack(List<(int, double)> segments) {
    final points = <TrackPoint>[
      const TrackPoint(lat: 16, lon: 108, tSec: 0, cumulativeM: 0),
    ];
    var t = 0.0;
    var d = 0.0;
    for (final (seconds, speed) in segments) {
      for (var i = 0; i < seconds; i++) {
        t += 1;
        d += speed;
        points.add(TrackPoint(lat: 16, lon: 108, tSec: t, cumulativeM: d));
      }
    }
    return points;
  }

  group('tìm khoảng đứng yên', () {
    test('track chạy đều từ đầu tới cuối thì không có khoảng dừng nào', () {
      final track = buildTrack([(120, 3.0)]);

      expect(ActivityMode.run.detectPausesIn(track), isEmpty);
    });

    test('đứng yên 60 giây giữa buổi thì bắt đúng khoảng đó', () {
      // 30 s chạy · 60 s đứng · 30 s chạy
      final track = buildTrack([(30, 3.0), (60, 0.0), (30, 3.0)]);

      final pauses = ActivityMode.run.detectPausesIn(track);

      expect(pauses, hasLength(1));
      expect(pauses.single.fromSec, closeTo(30, 1));
      expect(pauses.single.toSec, closeTo(90, 1));
      expect(pausedSeconds(pauses), closeTo(60, 2));
    });

    test('dừng ngắn hơn ngưỡng vào thì bỏ qua', () {
      // Chỉ 6 giây, dưới mốc 10 giây của chế độ Chạy — đèn đỏ chớp, không phải nghỉ.
      final track = buildTrack([(30, 3.0), (6, 0.0), (30, 3.0)]);

      expect(ActivityMode.run.detectPausesIn(track), isEmpty);
    });

    test('một nhịp nhanh ngắn giữa lúc đang dừng không cắt đôi khoảng dừng', () {
      // Đứng 30 s, nhích 2 giây (dưới mốc thoát 3 s), rồi đứng tiếp 30 s.
      final track = buildTrack([(20, 3.0), (30, 0.0), (2, 3.0), (30, 0.0), (20, 3.0)]);

      final pauses = ActivityMode.run.detectPausesIn(track);

      expect(pauses, hasLength(1), reason: 'nhiễu 2 giây không được tách thành hai khoảng');
      expect(pauses.single.durationSec, closeTo(62, 3));
    });

    test('đi tiếp đủ lâu thì đóng khoảng dừng, dừng lần nữa thì mở khoảng mới', () {
      final track = buildTrack([
        (20, 3.0),
        (30, 0.0), // dừng lần 1
        (40, 3.0), // chạy tiếp, quá mốc thoát 3 s
        (30, 0.0), // dừng lần 2
        (20, 3.0),
      ]);

      final pauses = ActivityMode.run.detectPausesIn(track);

      expect(pauses, hasLength(2));
      expect(pauses[0].durationSec, closeTo(30, 2));
      expect(pauses[1].durationSec, closeTo(30, 2));
    });

    test('track kết thúc lúc vẫn đang đứng yên thì vẫn tính khoảng cuối', () {
      // Quên bấm Dừng rồi mới tắt app.
      final track = buildTrack([(30, 3.0), (45, 0.0)]);

      final pauses = ActivityMode.run.detectPausesIn(track);

      expect(pauses, hasLength(1));
      expect(pauses.single.toSec, closeTo(75, 1));
    });

    test('bơi có ngưỡng vào cao hơn chạy, nên cùng một quãng đứng lại khác kết quả', () {
      // 15 giây đứng yên: quá mốc 10 s của Chạy, chưa tới mốc 20 s của Bơi.
      final track = buildTrack([(30, 1.0), (15, 0.0), (30, 1.0)]);

      expect(ActivityMode.run.detectPausesIn(track), hasLength(1));
      expect(ActivityMode.swim.detectPausesIn(track), isEmpty);
    });
  });

  group('không đụng vào dữ liệu gốc', () {
    test('danh sách điểm truyền vào giữ nguyên số lượng và giá trị', () {
      final track = buildTrack([(20, 3.0), (30, 0.0), (20, 3.0)]);
      final countBefore = track.length;
      final lastBefore = track.last;

      ActivityMode.run.detectPausesIn(track);

      expect(track.length, countBefore);
      expect(track.last.tSec, lastBefore.tSec);
      expect(track.last.cumulativeM, lastBefore.cumulativeM);
    });
  });

  group('trên buổi bơi thật ở Mỹ Khê', () {
    late List<TrackPoint> swim;

    setUpAll(() {
      final track = Gpx.decode(File('assets/data/Afternoon_Swim.gpx').readAsStringSync());
      final t0 = track.points.first.time!;
      final cumulative = cumulativeMeters(track.points);
      swim = [
        for (var i = 0; i < track.points.length; i++)
          TrackPoint(
            lat: track.points[i].lat,
            lon: track.points[i].lon,
            tSec: track.points[i].time!.difference(t0).inMilliseconds / 1000,
            cumulativeM: cumulative[i],
          ),
      ];
    });

    test('bơi biển gần như không có lúc đứng yên — tổng thời gian dừng nhỏ', () {
      final pauses = ActivityMode.swim.detectPausesIn(swim);

      // Nước đẩy người trôi liên tục nên ngưỡng 0,05 m/s hiếm khi bị phá.
      // Mốc này chốt lại hành vi: đổi thuật toán mà số nhảy vọt là phải xem lại.
      expect(pausedSeconds(pauses), lessThan(300));
    });

    test('chạy detector hai lần trên cùng dữ liệu ra kết quả giống hệt', () {
      expect(ActivityMode.swim.detectPausesIn(swim), ActivityMode.swim.detectPausesIn(swim));
    });
  });
}
