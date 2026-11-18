import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/storage/app_database.dart';
import 'package:pinkoo_stride/features/activity/data/repositories/activity_repository_local.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity/domain/repositories/activity_repository.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';

/// Xoá / đổi tên / ghi chú — ba thao tác người dùng làm trên hoạt động đã lưu.
void main() {
  late AppDatabase db;
  late ActivityRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repository = ActivityRepositoryLocal(db);
  });

  tearDown(() async => db.close());

  /// Dựng sẵn một hoạt động đã ghi xong, kèm vài điểm GPS.
  Future<int> seedActivity({String title = 'Buổi chạy chiều'}) async {
    final startedAt = DateTime.utc(2026, 10, 5, 7);
    final id = await repository.startRecording(
      mode: ActivityMode.run,
      title: title,
      startedAt: startedAt,
    );
    await repository.appendPoints(id, [
      for (var i = 0; i < 4; i++)
        TrackPoint(
          lat: 16.07 + i * 0.001,
          lon: 108.24,
          tSec: i * 10,
          cumulativeM: i * 110,
          accuracyM: 5,
        ),
    ]);
    await repository.finishRecording(
      id,
      endedAt: startedAt.add(const Duration(seconds: 30)),
      totals: const ActivityTotals(
        elapsedSec: 30,
        movingSec: 30,
        distanceM: 330,
        pointCount: 4,
      ),
    );
    return id;
  }

  group('xoá hoạt động', () {
    test('xoá xong thì không đọc lại được nữa', () async {
      final id = await seedActivity();
      expect(await repository.byId(id), isNotNull);

      await repository.delete(id);

      expect(await repository.byId(id), isNull);
    });

    test('điểm GPS bị xoá theo, không để lại rác trong bảng track_points', () async {
      final id = await seedActivity();
      expect(await db.managers.trackPoints.count(), 4);

      await repository.delete(id);

      // Ràng buộc ON DELETE CASCADE chỉ chạy khi PRAGMA foreign_keys bật — đây
      // chính là bài kiểm tra cho nó.
      expect(await db.managers.trackPoints.count(), 0);
    });

    test('xoá một buổi không đụng tới buổi khác', () async {
      final keep = await seedActivity(title: 'Giữ lại');
      final drop = await seedActivity(title: 'Xoá đi');

      await repository.delete(drop);

      expect(await repository.byId(drop), isNull);
      expect((await repository.byId(keep))?.title, 'Giữ lại');
    });
  });

  group('đổi tên', () {
    test('lưu tên mới và đọc lại đúng', () async {
      final id = await seedActivity();

      await repository.rename(id, 'Chạy cùng Mèo Bơ');

      expect((await repository.byId(id))?.title, 'Chạy cùng Mèo Bơ');
    });

    test('đổi tên không đụng tới số liệu đã ghi', () async {
      final id = await seedActivity();
      final before = await repository.byId(id);

      await repository.rename(id, 'Tên khác');
      final after = await repository.byId(id);

      expect(after?.distanceM, before?.distanceM);
      expect(after?.elapsedSec, before?.elapsedSec);
      expect(after?.points.length, before?.points.length);
    });
  });

  group('ghi chú', () {
    test('mới ghi xong thì chưa có ghi chú', () async {
      final id = await seedActivity();
      expect((await repository.byId(id))?.note, isNull);
    });

    test('lưu rồi đọc lại đúng nội dung', () async {
      final id = await seedActivity();

      await repository.updateNote(id, 'Trời mưa, chân hơi mỏi.');

      expect((await repository.byId(id))?.note, 'Trời mưa, chân hơi mỏi.');
    });

    test('truyền null thì xoá trắng ghi chú', () async {
      final id = await seedActivity();
      await repository.updateNote(id, 'Có ghi chú');

      await repository.updateNote(id, null);

      expect((await repository.byId(id))?.note, isNull);
    });

    test('ghi chú sống sót qua đổi tên', () async {
      final id = await seedActivity();
      await repository.updateNote(id, 'Giữ nguyên nhé');

      await repository.rename(id, 'Tên mới');

      final after = await repository.byId(id);
      expect(after?.title, 'Tên mới');
      expect(after?.note, 'Giữ nguyên nhé');
    });
  });
}
