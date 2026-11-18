import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/geo/gpx.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/activity.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/activity_mode/presentation/activity_mode_ui.dart';
import 'package:pinkoo_stride/features/share/data/gpx_export.dart';

Activity _activity({
  ActivityMode mode = ActivityMode.run,
  String title = 'Buổi chạy chiều',
}) => Activity(
  id: 7,
  mode: mode,
  title: title,
  startedAt: DateTime(2026, 10, 5, 7, 12),
  elapsedSec: 600,
  movingSec: 580,
  distanceM: 2000,
  pointCount: 2,
  points: const [
    TrackPoint(lat: 16.0731, lon: 108.2469, tSec: 0, cumulativeM: 0, elevationM: 3),
    TrackPoint(lat: 16.0796, lon: 108.2486, tSec: 600, cumulativeM: 2000, elevationM: 5),
  ],
);

void main() {
  group('tên file', () {
    test('có chế độ và mốc thời gian, sắp xếp được theo ngày', () {
      expect(
        GpxExport.fileNameFor(_activity()),
        'Pinkoo_Run_20261005_0712.gpx',
      );
      expect(
        GpxExport.fileNameFor(_activity(mode: ActivityMode.swim)),
        'Pinkoo_Swim_20261005_0712.gpx',
      );
    });

    test('không chứa ký tự tên hoạt động — tránh tên file lỗi', () {
      final name = GpxExport.fileNameFor(_activity(title: 'Chạy / "biển" <sáng>'));
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('"')));
      expect(name, endsWith('.gpx'));
    });

    test('mỗi chế độ ra một tên khác nhau', () {
      final names = ActivityMode.values
          .map((m) => GpxExport.fileNameFor(_activity(mode: m)))
          .toSet();
      expect(names.length, ActivityMode.values.length);
    });
  });

  group('nội dung GPX', () {
    test('ghi đúng loại môn để Strava/Garmin nhận ra', () {
      expect(ActivityMode.run.gpxType, 'running');
      expect(ActivityMode.walk.gpxType, 'walking');
      expect(ActivityMode.swim.gpxType, 'swimming');
      expect(ActivityMode.ride.gpxType, 'cycling');
    });

    test('mốc thời gian mỗi điểm = thời điểm bắt đầu + tSec', () {
      final activity = _activity();
      final xml = Gpx.encode(
        trackName: activity.title,
        startedAt: activity.startedAt,
        trackType: activity.mode.gpxType,
        points: [
          for (final p in activity.points)
            (lat: p.lat, lon: p.lon, tSec: p.tSec, elevationM: p.elevationM),
        ],
      );

      final reread = Gpx.decode(xml);
      expect(reread.type, 'running');
      expect(reread.points.first.time, activity.startedAt.toUtc());
      expect(
        reread.points.last.time,
        activity.startedAt.toUtc().add(const Duration(seconds: 600)),
      );
      expect(reread.elapsedSec, 600);
      expect(reread.points.first.elevationM, 3);
    });
  });
}
