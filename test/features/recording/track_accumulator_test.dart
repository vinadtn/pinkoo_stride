import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/geo/gpx.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/recording/domain/raw_fix.dart';
import 'package:pinkoo_stride/features/recording/domain/track_accumulator.dart';

void main() {
  group('phát lại buổi bơi thật qua TrackAccumulator', () {
    late TrackAccumulator acc;
    late GpxTrack track;

    setUpAll(() {
      track = Gpx.decode(File('assets/data/Afternoon_Swim.gpx').readAsStringSync());
      acc = TrackAccumulator(mode: ActivityMode.swim);
      for (final p in track.points) {
        acc.add(
          RawFix(lat: p.lat, lon: p.lon, timestamp: p.time!, elevationM: p.elevationM),
        );
      }
    });

    test('bỏ đúng 5 điểm hàm ý bơi nhanh hơn 10 km/h', () {
      // Prototype không lọc gì nên giữ cả 3.812 điểm. App thì lọc: 5 đoạn
      // trong file này cho ra tốc độ > 2,78 m/s (10 km/h) — kỷ lục thế giới
      // 100 m tự do còn chưa tới 2,4 m/s, nên đó là GPS nhảy chứ không phải
      // người bơi. Bỏ chúng đi là ĐÚNG, dù số cuối lệch prototype một chút.
      expect(acc.pointCount, 3807);
      expect(acc.rejections, {FixRejection.impossibleJump: 5});
    });

    test('quãng đường 2.116,1 m — ngắn hơn prototype 9,7 m vì đã lọc GPS nhảy', () {
      expect(acc.distanceM, closeTo(2116.1, 0.1));
      // Vẫn phải sát con số gốc: lọc chỉ được cắt nhiễu, không được cắt mất
      // cả đoạn đường thật.
      expect(acc.distanceM, closeTo(2125.8, 15));
    });

    test('thời gian 1:03:46 và di chuyển 1:03:14', () {
      expect(acc.elapsedSec, closeTo(3826, 0.01));
      // Prototype ghi "Thời gian di chuyển 1:03:14" = 3.794 s.
      expect(acc.movingSec, closeTo(3794, 1));
    });

    test('cumulativeM tăng dần và điểm cuối bằng tổng quãng đường', () {
      var prev = -1.0;
      for (final p in acc.points) {
        expect(p.cumulativeM, greaterThanOrEqualTo(prev));
        prev = p.cumulativeM;
      }
      expect(acc.points.last.cumulativeM, closeTo(acc.distanceM, 1e-6));
    });

    test('tSec của điểm đầu là 0 và tăng dần', () {
      expect(acc.points.first.tSec, 0);
      var prev = -1.0;
      for (final p in acc.points) {
        expect(p.tSec, greaterThan(prev));
        prev = p.tSec;
      }
    });
  });

  group('lọc điểm rác', () {
    final t0 = DateTime.utc(2026, 10, 5, 7);

    test('bỏ điểm có sai số lớn hơn ngưỡng của chế độ', () {
      final acc = TrackAccumulator(mode: ActivityMode.run); // ngưỡng 20 m
      expect(acc.add(RawFix(lat: 16, lon: 108, timestamp: t0, accuracyM: 8)), isNull);
      expect(
        acc.add(RawFix(lat: 16.0001, lon: 108, timestamp: t0.add(_s(5)), accuracyM: 45)),
        FixRejection.poorAccuracy,
      );
      expect(acc.pointCount, 1);
      expect(acc.rejections[FixRejection.poorAccuracy], 1);
    });

    test('chế độ Bơi nới ngưỡng sai số lên 30 m nên vẫn nhận điểm 25 m', () {
      final acc = TrackAccumulator(mode: ActivityMode.swim);
      expect(acc.add(RawFix(lat: 16, lon: 108, timestamp: t0, accuracyM: 25)), isNull);
      expect(acc.pointCount, 1);
    });

    test('bỏ điểm nhảy xa quá mức tốc độ cho phép', () {
      final acc = TrackAccumulator(mode: ActivityMode.run); // tối đa 6,95 m/s
      acc.add(RawFix(lat: 16, lon: 108, timestamp: t0));
      // ~1,1 km trong 1 s → chắc chắn là GPS nhảy.
      expect(
        acc.add(RawFix(lat: 16.01, lon: 108, timestamp: t0.add(_s(1)))),
        FixRejection.impossibleJump,
      );
      expect(acc.distanceM, 0);
      expect(acc.pointCount, 1);
    });

    test('điểm nhảy bị bỏ không phá mốc so sánh của điểm hợp lệ tiếp theo', () {
      final acc = TrackAccumulator(mode: ActivityMode.run);
      acc.add(RawFix(lat: 16, lon: 108, timestamp: t0));
      acc.add(RawFix(lat: 16.01, lon: 108, timestamp: t0.add(_s(1)))); // bị bỏ
      // ~11 m trong 4 s = 2,8 m/s: hợp lệ, và phải đo từ điểm ĐẦU, không phải
      // từ điểm nhảy vừa bị bỏ.
      expect(acc.add(RawFix(lat: 16.0001, lon: 108, timestamp: t0.add(_s(4)))), isNull);
      expect(acc.distanceM, closeTo(11.1, 0.3));
    });

    test('bỏ điểm có mốc thời gian không tiến lên', () {
      final acc = TrackAccumulator(mode: ActivityMode.run);
      acc.add(RawFix(lat: 16, lon: 108, timestamp: t0.add(_s(10))));
      expect(
        acc.add(RawFix(lat: 16.00005, lon: 108, timestamp: t0.add(_s(10)))),
        FixRejection.notMovingForward,
      );
      expect(
        acc.add(RawFix(lat: 16.00005, lon: 108, timestamp: t0.add(_s(3)))),
        FixRejection.notMovingForward,
      );
    });

    test('đứng yên vẫn nhận điểm nhưng không cộng thời gian di chuyển', () {
      final acc = TrackAccumulator(mode: ActivityMode.run); // ngưỡng 0,5 m/s
      acc.add(RawFix(lat: 16, lon: 108, timestamp: t0));
      // Nhích 0,5 m trong 10 s = 0,05 m/s → đang đứng.
      acc.add(RawFix(lat: 16.0000045, lon: 108, timestamp: t0.add(_s(10))));
      expect(acc.pointCount, 2);
      expect(acc.movingSec, 0);
      expect(acc.elapsedSec, 10);
    });
  });

  group('tạm dừng', () {
    final t0 = DateTime.utc(2026, 10, 5, 7);

    test('điểm nạp lúc đang dừng bị bỏ', () {
      final acc = TrackAccumulator(mode: ActivityMode.run)
        ..add(RawFix(lat: 16, lon: 108, timestamp: t0))
        ..pause(t0.add(_s(10)));
      expect(acc.isPaused, isTrue);
      expect(
        acc.add(RawFix(lat: 16.0001, lon: 108, timestamp: t0.add(_s(20)))),
        FixRejection.paused,
      );
      expect(acc.pointCount, 1);
    });

    test('thời gian tạm dừng không tính vào elapsed', () {
      final acc = TrackAccumulator(mode: ActivityMode.run)
        ..add(RawFix(lat: 16, lon: 108, timestamp: t0))
        ..pause(t0.add(_s(10)))
        ..resume(t0.add(_s(70))); // nghỉ 60 s
      acc.add(RawFix(lat: 16.0002, lon: 108, timestamp: t0.add(_s(80))));
      // Thật ra đã 80 s trôi qua, nhưng 60 s là nghỉ → đồng hồ chỉ 20 s.
      expect(acc.elapsedSec, closeTo(20, 0.01));
    });

    test('đoạn vắt qua lúc nghỉ không bị cộng vào quãng đường', () {
      final acc = TrackAccumulator(mode: ActivityMode.run)
        ..add(RawFix(lat: 16, lon: 108, timestamp: t0))
        ..pause(t0.add(_s(5)));
      // Người dùng lên xe đi 2 km rồi mới bấm tiếp tục — không được tính là chạy.
      acc.resume(t0.add(_s(600)));
      acc.add(RawFix(lat: 16.02, lon: 108, timestamp: t0.add(_s(601))));
      expect(acc.pointCount, 2);
      expect(acc.distanceM, 0);
    });

    test('dừng hai lần liền không cộng dồn sai, tiếp tục khi chưa dừng là no-op', () {
      final acc = TrackAccumulator(mode: ActivityMode.run)
        ..add(RawFix(lat: 16, lon: 108, timestamp: t0))
        ..resume(t0.add(_s(1))) // chưa dừng → không làm gì
        ..pause(t0.add(_s(10)))
        ..pause(t0.add(_s(20))) // lần hai bị bỏ qua
        ..resume(t0.add(_s(40)));
      acc.add(RawFix(lat: 16.0002, lon: 108, timestamp: t0.add(_s(50))));
      // Nghỉ tính từ giây 10 tới 40 = 30 s; elapsed = 50 - 30 = 20 s.
      expect(acc.elapsedSec, closeTo(20, 0.01));
    });
  });

  group('phục hồi sau khi app bị kill', () {
    final t0 = DateTime.utc(2026, 10, 5, 7);

    test('đồng hồ tiếp tục từ đúng chỗ cũ, không nhảy thêm khoảng app chết', () {
      final acc = TrackAccumulator(mode: ActivityMode.run)
        ..restore(
          startedAt: t0,
          // App chết ở giây 300, mở lại ở giây 900 → 600 s đó không phải vận động.
          resumedAt: t0.add(_s(900)),
          points: const [
            TrackPoint(lat: 16, lon: 108, tSec: 0, cumulativeM: 0),
            TrackPoint(lat: 16.002, lon: 108, tSec: 300, cumulativeM: 222.4),
          ],
          movingSec: 290,
        );

      expect(acc.distanceM, closeTo(222.4, 0.01));
      expect(acc.movingSec, 290);
      expect(acc.pointCount, 2);

      acc.add(RawFix(lat: 16.0021, lon: 108, timestamp: t0.add(_s(905))));
      expect(acc.elapsedSec, closeTo(305, 0.01));
    });

    test('điểm đầu sau khi phục hồi không nối vào điểm cũ', () {
      final acc = TrackAccumulator(mode: ActivityMode.run)
        ..restore(
          startedAt: t0,
          resumedAt: t0.add(_s(900)),
          points: const [TrackPoint(lat: 16, lon: 108, tSec: 300, cumulativeM: 222.4)],
          movingSec: 290,
        );
      // Mở lại app ở cách đó 300 m — không được cộng 300 m này vào quãng đường.
      acc.add(RawFix(lat: 16.0027, lon: 108, timestamp: t0.add(_s(905))));
      expect(acc.distanceM, closeTo(222.4, 0.01));
    });
  });
}

Duration _s(int seconds) => Duration(seconds: seconds);
