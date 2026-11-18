import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/logger/app_logger.dart';
import 'package:pinkoo_stride/core/storage/app_database.dart';
import 'package:pinkoo_stride/core/storage/local_storage.dart';
import 'package:pinkoo_stride/features/activity/data/repositories/activity_repository_local.dart';
import 'package:pinkoo_stride/features/activity/domain/entities/track_point.dart';
import 'package:pinkoo_stride/features/activity/domain/repositories/activity_repository.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/backup/data/backup_archive.dart';
import 'package:pinkoo_stride/features/backup/data/backup_codec.dart';
import 'package:pinkoo_stride/features/backup/data/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Khôi phục thật: xuất từ một máy, nạp vào máy trắng, rồi nạp CHỒNG lần nữa.
/// Lần thứ hai không được nhân đôi lịch sử.
void main() {
  late AppDatabase db;
  late ActivityRepository repository;
  late BackupService service;

  Future<BackupService> makeService(ActivityRepository repo) async {
    SharedPreferences.setMockInitialValues({});
    return BackupService(
      repo,
      LocalStorage(await SharedPreferences.getInstance()),
      AppLogger(enabled: false),
    );
  }

  setUpAll(() {
    // Test này cố ý dựng hai AppDatabase (giả lập hai máy), nên tắt cảnh báo.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repository = ActivityRepositoryLocal(db);
    service = await makeService(repository);
  });

  tearDown(() async => db.close());

  Future<int> seed({
    required ActivityMode mode,
    required DateTime startedAt,
    String title = 'Buổi tập',
    String? note,
  }) async {
    final id = await repository.startRecording(
      mode: mode,
      title: title,
      startedAt: startedAt,
    );
    await repository.appendPoints(id, [
      for (var i = 0; i < 3; i++)
        TrackPoint(
          lat: 16.07 + i * 0.001,
          lon: 108.24,
          tSec: i * 60,
          cumulativeM: i * 500,
          accuracyM: 5,
        ),
    ]);
    await repository.finishRecording(
      id,
      endedAt: startedAt.add(const Duration(minutes: 2)),
      totals: const ActivityTotals(
        elapsedSec: 120,
        movingSec: 115,
        distanceM: 1000,
        pointCount: 3,
        calories: 90,
      ),
    );
    if (note != null) await repository.updateNote(id, note);
    return id;
  }

  /// Xuất dữ liệu hiện có thành byte gói sao lưu.
  Future<List<int>> exportBytes() async =>
      BackupArchive.encode(activities: await repository.allForBackup(), settings: const {});

  test('nạp vào máy trắng thì về đủ hoạt động, đủ điểm và đủ ghi chú', () async {
    await seed(
      mode: ActivityMode.run,
      startedAt: DateTime.utc(2026, 10, 6, 7),
      title: 'Chạy sáng',
      note: 'Chân nhẹ',
    );
    await seed(mode: ActivityMode.swim, startedAt: DateTime.utc(2026, 10, 6, 15));
    final bytes = await exportBytes();

    // "Máy mới": DB trắng tinh.
    final fresh = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    final freshRepo = ActivityRepositoryLocal(fresh);
    final freshService = await makeService(freshRepo);

    final plan = await freshService.plan(Uint8List.fromList(bytes));
    expect(plan.fresh, hasLength(2));
    expect(plan.duplicates, isEmpty);

    final added = await freshService.apply(plan);
    expect(added, 2);

    final restored = await freshRepo.allForBackup();
    expect(restored, hasLength(2));
    expect(restored.map((a) => a.title), containsAll(['Chạy sáng', 'Buổi tập']));
    expect(restored.firstWhere((a) => a.title == 'Chạy sáng').note, 'Chân nhẹ');
    expect(restored.every((a) => a.points.length == 3), isTrue);

    await fresh.close();
  });

  test('nạp lại chính gói đó thì nhận ra trùng hết, không thêm gì', () async {
    await seed(mode: ActivityMode.run, startedAt: DateTime.utc(2026, 10, 6, 7));
    final bytes = await exportBytes();

    final plan = await service.plan(Uint8List.fromList(bytes));

    expect(plan.fresh, isEmpty);
    expect(plan.duplicates, hasLength(1));
    expect(await service.apply(plan), 0);
    expect(await repository.allForBackup(), hasLength(1), reason: 'không được nhân đôi');
  });

  test('chọn "thêm hết" thì cố ý nhập cả bản trùng', () async {
    await seed(mode: ActivityMode.run, startedAt: DateTime.utc(2026, 10, 6, 7));
    final bytes = await exportBytes();

    final plan = await service.plan(Uint8List.fromList(bytes));
    final added = await service.apply(plan, includeDuplicates: true);

    expect(added, 1);
    expect(await repository.allForBackup(), hasLength(2));
  });

  test('hai buổi khác chế độ cùng giờ KHÔNG bị coi là trùng nhau', () async {
    final at = DateTime.utc(2026, 10, 6, 7);
    await seed(mode: ActivityMode.run, startedAt: at);
    await seed(mode: ActivityMode.swim, startedAt: at);
    final bytes = await exportBytes();

    final fresh = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    final freshService = await makeService(ActivityRepositoryLocal(fresh));

    final plan = await freshService.plan(Uint8List.fromList(bytes));

    expect(plan.fresh, hasLength(2));
    await fresh.close();
  });

  test('gói hỏng thì ném BackupFormatException, không đụng tới DB', () async {
    await seed(mode: ActivityMode.run, startedAt: DateTime.utc(2026, 10, 6, 7));

    await expectLater(
      service.plan(Uint8List.fromList('rac'.codeUnits)),
      throwsA(isA<BackupFormatException>()),
    );
    expect(await repository.allForBackup(), hasLength(1));
  });
}
