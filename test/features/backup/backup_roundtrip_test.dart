import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/activity.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/backup/data/backup_archive.dart';
import 'package:pinkoo_stride/features/backup/data/backup_codec.dart';
import 'package:pinkoo_stride/features/backup/domain/backup_data.dart';

/// Sao lưu chỉ có giá trị nếu NẠP LẠI ĐƯỢC. Bài test ở đây đi trọn vòng
/// xuất → nén → giải nén → nhập, rồi đối chiếu từng con số.
void main() {
  Activity sample({
    int id = 1,
    ActivityMode mode = ActivityMode.run,
    String title = 'Buổi chạy chiều',
    String? note,
    int minute = 0,
  }) {
    final startedAt = DateTime.utc(2026, 10, 6, 7, minute);
    return Activity(
      id: id,
      mode: mode,
      title: title,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 30)),
      elapsedSec: 1800,
      movingSec: 1750,
      distanceM: 5230.5,
      pointCount: 3,
      calories: 412.5,
      elevationGainM: 23.5,
      placeLabel: 'Bãi biển Mỹ Khê',
      note: note,
      points: const [
        TrackPoint(lat: 16.073, lon: 108.247, tSec: 0, cumulativeM: 0, elevationM: 2),
        TrackPoint(lat: 16.074, lon: 108.248, tSec: 900, cumulativeM: 2600, accuracyM: 5),
        TrackPoint(lat: 16.075, lon: 108.249, tSec: 1800, cumulativeM: 5230.5, speedMps: 2.9),
      ],
    );
  }

  group('đi trọn vòng xuất rồi nhập', () {
    test('mọi số liệu và chữ người dùng nhập đều về nguyên vẹn', () {
      final original = sample(note: 'Trời mưa, chân hơi mỏi.');

      final bytes = BackupArchive.encode(activities: [original], settings: const {});
      final restored = BackupArchive.decode(bytes).activities.single;

      expect(restored.mode, original.mode);
      expect(restored.title, original.title);
      expect(restored.note, original.note);
      expect(restored.startedAt, original.startedAt);
      expect(restored.endedAt, original.endedAt);
      expect(restored.elapsedSec, original.elapsedSec);
      expect(restored.movingSec, original.movingSec);
      expect(restored.distanceM, original.distanceM);
      expect(restored.pointCount, original.pointCount);
      expect(restored.calories, original.calories);
      expect(restored.elevationGainM, original.elevationGainM);
      expect(restored.placeLabel, original.placeLabel);
    });

    test('từng điểm GPS giữ nguyên toạ độ, thời gian và quãng đường cộng dồn', () {
      final original = sample();

      final bytes = BackupArchive.encode(activities: [original], settings: const {});
      final restored = BackupArchive.decode(bytes).activities.single;

      expect(restored.points, hasLength(original.points.length));
      for (var i = 0; i < original.points.length; i++) {
        expect(restored.points[i].lat, original.points[i].lat);
        expect(restored.points[i].lon, original.points[i].lon);
        expect(restored.points[i].tSec, original.points[i].tSec);
        expect(restored.points[i].cumulativeM, original.points[i].cumulativeM);
        expect(restored.points[i].elevationM, original.points[i].elevationM);
        expect(restored.points[i].accuracyM, original.points[i].accuracyM);
        expect(restored.points[i].speedMps, original.points[i].speedMps);
      }
    });

    test('ghi chú trống vẫn là null sau khi nhập, không thành chuỗi rỗng', () {
      final bytes = BackupArchive.encode(activities: [sample()], settings: const {});

      expect(BackupArchive.decode(bytes).activities.single.note, isNull);
    });
  });

  group('manifest', () {
    test('đếm đúng số hoạt động và số điểm', () {
      final bytes = BackupArchive.encode(
        activities: [sample(id: 1), sample(id: 2, minute: 40)],
        settings: const {},
      );

      final manifest = BackupArchive.decode(bytes).manifest;

      expect(manifest.formatVersion, backupFormatVersion);
      expect(manifest.activityCount, 2);
      expect(manifest.pointCount, 6);
      expect(manifest.isReadable, isTrue);
    });

    test('định dạng mới hơn app thì từ chối, không cố đọc', () {
      final future = BackupManifest(
        formatVersion: backupFormatVersion + 1,
        exportedAt: DateTime.utc(2026, 10, 6),
        activityCount: 0,
        pointCount: 0,
      );

      expect(future.isReadable, isFalse);
    });
  });

  group('file hỏng thì báo lỗi rõ ràng', () {
    test('không phải zip', () {
      expect(
        () => BackupArchive.decode(Uint8List.fromList('day khong phai zip'.codeUnits)),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('kèm file .gpx để mang sang Strava/Garmin', () {
    test('mỗi hoạt động có điểm đều có một file trong gpx/', () {
      final bytes = BackupArchive.encode(
        activities: [sample(id: 1), sample(id: 2, mode: ActivityMode.swim, minute: 40)],
        settings: const {},
      );

      final names = ZipDecoder()
          .decodeBytes(bytes)
          .files
          .map((f) => f.name)
          .where((n) => n.startsWith('${BackupEntry.gpxDir}/'))
          .toList();

      expect(names, hasLength(2));
      expect(names.every((n) => n.endsWith('.gpx')), isTrue);
    });

    test('gói luôn có đủ ba file mô tả', () {
      final bytes = BackupArchive.encode(activities: [sample()], settings: const {});

      final names = ZipDecoder().decodeBytes(bytes).files.map((f) => f.name).toSet();

      expect(names, containsAll([
        BackupEntry.manifest,
        BackupEntry.activities,
        BackupEntry.settings,
      ]));
    });
  });

  group('codec', () {
    test('activities.json sai kiểu thì ném BackupFormatException', () {
      expect(
        () => BackupCodec.activitiesFromJson({'khong': 'phai list'}),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('hoạt động thiếu mốc bắt đầu thì ném lỗi chứ không nhận bừa', () {
      expect(
        () => BackupCodec.activityFromJson(const {'mode': 'run', 'title': 'X'}),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
