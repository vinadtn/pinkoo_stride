import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/features/activity/domain/auto_pause_stats.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/activity.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';

/// Công tắc auto-pause ở màn lịch sử chỉ TÍNH LẠI, không ghi đè.
void main() {
  /// Track thẳng, mỗi giây một điểm, tốc độ đặt theo từng chặng.
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

  Activity activityOf(List<TrackPoint> points) => Activity(
    id: 1,
    mode: ActivityMode.run,
    title: 'Buổi chạy chiều',
    startedAt: DateTime.utc(2026, 10, 6, 7),
    elapsedSec: points.last.tSec.round(),
    movingSec: points.last.tSec.round(),
    distanceM: points.last.cumulativeM,
    pointCount: points.length,
    points: points,
  );

  // 60 s chạy · 60 s đứng · 60 s chạy → 180 s tổng, 60 s đứng yên.
  final withStop = activityOf(buildTrack([(60, 3.0), (60, 0.0), (60, 3.0)]));

  test('trừ đúng khoảng đứng yên khỏi thời gian', () {
    final stats = autoPauseStatsOf(withStop)!;

    expect(stats.hasPauses, isTrue);
    expect(stats.pausedSec, closeTo(60, 2));
    expect(stats.elapsedSec, closeTo(120, 2));
  });

  test('quãng đường KHÔNG đổi — auto-pause chỉ bỏ thời gian', () {
    final stats = autoPauseStatsOf(withStop)!;

    expect(stats.distanceM, withStop.distanceM);
  });

  test('pace nhanh lên đúng tỉ lệ thời gian bị trừ', () {
    final stats = autoPauseStatsOf(withStop)!;

    // Bỏ 1/3 thời gian thì pace phải nhanh hơn, và bằng đúng thời-gian-mới / km.
    expect(stats.secPerKm, lessThan(withStop.secPerKm));
    expect(stats.secPerKm, closeTo(stats.elapsedSec / (stats.distanceM / 1000), 0.01));
  });

  test('không đụng vào bản ghi gốc', () {
    final elapsedBefore = withStop.elapsedSec;
    final distanceBefore = withStop.distanceM;

    autoPauseStatsOf(withStop);

    expect(withStop.elapsedSec, elapsedBefore);
    expect(withStop.distanceM, distanceBefore);
    expect(withStop.secPerKm, closeTo(elapsedBefore / (distanceBefore / 1000), 0.01));
  });

  test('chạy đều không nghỉ thì không có gì để trừ', () {
    final nonstop = activityOf(buildTrack([(180, 3.0)]));

    final stats = autoPauseStatsOf(nonstop)!;

    expect(stats.hasPauses, isFalse);
    expect(stats.pausedSec, 0);
    expect(stats.elapsedSec, nonstop.elapsedSec.toDouble());
  });

  test('hoạt động chưa nạp điểm GPS thì trả null, không nổ', () {
    final noPoints = Activity(
      id: 2,
      mode: ActivityMode.run,
      title: 'Thẻ trong bảng tin',
      startedAt: DateTime.utc(2026, 10, 6, 7),
      elapsedSec: 100,
      movingSec: 100,
      distanceM: 300,
      pointCount: 0,
    );

    expect(autoPauseStatsOf(noPoints), isNull);
  });
}
