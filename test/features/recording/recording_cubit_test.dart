import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/core/geo/gpx.dart';
import 'package:pinkoo_stride/core/logger/app_logger.dart';
import 'package:pinkoo_stride/core/storage/app_database.dart';
import 'package:pinkoo_stride/core/storage/local_storage.dart';
import 'package:pinkoo_stride/features/activity/data/repositories/activity_repository_local.dart';
import 'package:pinkoo_stride/features/activity/domain/repositories/activity_repository.dart';
import 'package:pinkoo_stride/features/activity_mode/domain/activity_mode.dart';
import 'package:pinkoo_stride/features/recording/data/location_service.dart';
import 'package:pinkoo_stride/features/recording/domain/raw_fix.dart';
import 'package:pinkoo_stride/features/recording/domain/split_alert.dart';
import 'package:pinkoo_stride/features/recording/presentation/cubit/recording_cubit.dart';
import 'package:pinkoo_stride/features/recording/presentation/cubit/recording_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kiểm thử end-to-end luồng ghi, KHÔNG cần thiết bị thật:
/// phát lại `Afternoon_Swim.gpx` qua một LocationService giả → RecordingCubit →
/// SQLite trong RAM, rồi đối chiếu bản ghi cuối với mốc đã biết.
///
/// Đây là bài test thay cho việc phải ra biển bơi một tiếng mỗi lần sửa code.
void main() {
  late AppDatabase db;
  late ActivityRepository repository;
  late LocalStorage storage;
  late List<RawFix> swimFixes;

  setUpAll(() {
    final track = Gpx.decode(File('assets/data/Afternoon_Swim.gpx').readAsStringSync());
    swimFixes = [
      for (final p in track.points)
        RawFix(lat: p.lat, lon: p.lon, timestamp: p.time!, elevationM: p.elevationM),
    ];
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    repository = ActivityRepositoryLocal(db);
  });

  tearDown(() async => db.close());

  RecordingCubit makeCubit({ActivityMode mode = ActivityMode.swim, List<RawFix>? fixes}) =>
      RecordingCubit(
        location: _FakeLocationService(fixes ?? swimFixes),
        repository: repository,
        storage: storage,
        logger: AppLogger(enabled: false),
        initialMode: mode,
      );

  group('ghi một buổi trọn vẹn', () {
    test('lưu đúng quãng đường, thời gian và số điểm vào DB', () async {
      final cubit = makeCubit();
      await cubit.start();
      await _waitUntil(() => cubit.state.pointCount >= swimFixes.length - 5);
      await cubit.finish();

      expect(cubit.state.status, RecordingStatus.saved);
      final id = cubit.state.savedActivityId;
      expect(id, isNotNull);

      final saved = await repository.byId(id!);
      expect(saved, isNotNull);
      expect(saved!.mode, ActivityMode.swim);
      // 5 điểm bị lọc vì hàm ý bơi > 10 km/h — xem track_accumulator_test.dart.
      expect(saved.pointCount, 3807);
      expect(saved.distanceM, closeTo(2116.1, 0.5));
      expect(saved.points.length, 3807);
      expect(saved.calories, greaterThan(0));

      await cubit.close();
    });

    test('điểm GPS được ghi xuống DB NGAY trong lúc ghi, không chờ bấm Dừng', () async {
      final cubit = makeCubit();
      await cubit.start();
      await _waitUntil(() => cubit.state.pointCount > 100);

      // Chưa finish mà đã phải thấy bản ghi "đang ghi" kèm điểm trong DB —
      // đây chính là thứ giúp phục hồi khi app bị kill.
      final inProgress = await repository.findUnfinished();
      expect(inProgress, isNotNull);
      expect(inProgress!.points, isNotEmpty);

      await cubit.close();
    });

    test('buổi quá ngắn thì không lưu và dọn luôn bản ghi', () async {
      // 3 điểm sát nhau → dưới 50 m.
      final t0 = DateTime.utc(2026, 10, 5, 7);
      final cubit = makeCubit(
        mode: ActivityMode.run,
        fixes: [
          RawFix(lat: 16, lon: 108, timestamp: t0, accuracyM: 5),
          RawFix(lat: 16.00005, lon: 108, timestamp: t0.add(const Duration(seconds: 5)), accuracyM: 5),
          RawFix(lat: 16.0001, lon: 108, timestamp: t0.add(const Duration(seconds: 10)), accuracyM: 5),
        ],
      );
      await cubit.start();
      await _waitUntil(() => cubit.state.pointCount >= 3);
      await cubit.finish();

      expect(cubit.state.status, RecordingStatus.tooShort);
      expect(await repository.findUnfinished(), isNull);
      await cubit.close();
    });

    test('bỏ buổi đang ghi thì xoá sạch khỏi DB', () async {
      final cubit = makeCubit();
      await cubit.start();
      await _waitUntil(() => cubit.state.pointCount > 20);
      await cubit.discard();

      expect(cubit.state.status, RecordingStatus.discarded);
      expect(await repository.findUnfinished(), isNull);
      await cubit.close();
    });
  });

  group('chọn chế độ', () {
    test('nhớ chế độ đã chọn cho lần mở sau', () async {
      final first = makeCubit(mode: ActivityMode.run)..selectMode(ActivityMode.ride);
      await first.close();

      // Cubit mới đọc lại từ storage, không truyền initialMode.
      final second = RecordingCubit(
        location: _FakeLocationService(const []),
        repository: repository,
        storage: storage,
        logger: AppLogger(enabled: false),
      );
      expect(second.state.mode, ActivityMode.ride);
      await second.close();
    });

    test('đang ghi thì không cho đổi chế độ giữa buổi', () async {
      final cubit = makeCubit(mode: ActivityMode.swim);
      await cubit.start();
      cubit.selectMode(ActivityMode.ride);
      expect(cubit.state.mode, ActivityMode.swim);
      await cubit.close();
    });
  });

  group('phục hồi sau khi app bị kill', () {
    test('tìm thấy buổi dở và lưu lại được', () async {
      // Buổi 1: ghi một đoạn rồi "app chết" (close mà không finish).
      final crashed = makeCubit();
      await crashed.start();
      await _waitUntil(() => crashed.state.pointCount > 200);
      final distanceBefore = crashed.state.distanceM;
      await crashed.close();

      // Buổi 2: mở lại app.
      final reopened = makeCubit();
      await reopened.checkUnfinished();
      expect(reopened.state.unfinished, isNotNull);
      expect(reopened.state.unfinished!.mode, ActivityMode.swim);

      await reopened.saveUnfinished();
      expect(reopened.state.status, RecordingStatus.saved);

      final saved = await repository.byId(reopened.state.savedActivityId!);
      expect(saved!.distanceM, closeTo(distanceBefore, 50));
      // Đã chốt rồi thì không còn nằm trong diện "đang ghi".
      expect(await repository.findUnfinished(), isNull);
      await reopened.close();
    });

    test('bỏ buổi dở thì xoá khỏi DB', () async {
      final crashed = makeCubit();
      await crashed.start();
      await _waitUntil(() => crashed.state.pointCount > 50);
      await crashed.close();

      final reopened = makeCubit();
      await reopened.checkUnfinished();
      await reopened.discardUnfinished();

      expect(reopened.state.unfinished, isNull);
      expect(await repository.findUnfinished(), isNull);
      await reopened.close();
    });

    test('bấm Bắt đầu buổi mới thì dọn buổi dở cũ, không để treo hai bản ghi', () async {
      final crashed = makeCubit();
      await crashed.start();
      await _waitUntil(() => crashed.state.pointCount > 20);
      await crashed.close();

      final fresh = makeCubit();
      await fresh.start();
      await _waitUntil(() => fresh.state.pointCount > 5);

      final recordings = await db.managers.activities
          .filter((f) => f.status.equals(ActivityStatus.recording))
          .get();
      expect(recordings.length, 1);
      await fresh.close();
    });
  });

  group('điểm mồi lúc đứng yên', () {
    // Hồi quy: `getPositionStream` đặt distanceFilter 3–10 m nên đứng chờ xuất
    // phát là KHÔNG có điểm nào. Trước khi có điểm mồi, `lastAccuracyM` còn null
    // và chip trên màn ghi đứng mãi ở "Đang tìm tín hiệu GPS…" dù bản đồ đã vẽ
    // được chấm xanh (Mapbox lấy vị trí riêng, không qua dòng này).
    test('dòng vị trí chưa phát điểm nào thì vẫn có sai số để hiện chất lượng GPS', () async {
      final cubit = RecordingCubit(
        location: _SilentStreamLocationService(),
        repository: repository,
        storage: storage,
        logger: AppLogger(enabled: false),
        initialMode: ActivityMode.run,
      );
      await cubit.start();
      await _waitUntil(() => cubit.state.lastAccuracyM != null);

      expect(cubit.state.gpsQuality, GpsQuality.good);
      expect(cubit.state.pointCount, 1);
      await cubit.close();
    });
  });

  group('báo chặng', () {
    test('bơi 2,1 km thì báo đủ các mốc 100 m, không trùng không sót', () async {
      final heard = _RecordingAnnouncer();
      final cubit = RecordingCubit(
        location: _FakeLocationService(swimFixes),
        repository: repository,
        storage: storage,
        logger: AppLogger(enabled: false),
        splitAnnouncer: heard,
        initialMode: ActivityMode.swim,
      );

      await cubit.start();
      await _waitUntil(() => cubit.state.pointCount >= swimFixes.length - 5);
      await cubit.finish();

      // Quãng bơi 2.116 m → 21 mốc 100 m.
      expect(heard.alerts.map((a) => a.index).toList(), [for (var i = 1; i <= 21; i++) i]);
      expect(heard.alerts.every((a) => a.mode == ActivityMode.swim), isTrue);
      await cubit.close();
    });

    test('mặc định im lặng: không truyền announcer thì không báo gì', () async {
      // Cubit dựng qua makeCubit() dùng SilentSplitAnnouncer — chạy trọn buổi
      // mà không nổ, tức là đường mặc định vẫn an toàn.
      final cubit = makeCubit();
      await cubit.start();
      await _waitUntil(() => cubit.state.distanceM > 300);
      await cubit.finish();

      expect(cubit.state.status, RecordingStatus.saved);
      await cubit.close();
    });
  });
}

/// Ghi lại các lần báo chặng thay vì rung hay nói.
class _RecordingAnnouncer implements SplitAnnouncer {
  final List<SplitAlert> alerts = [];

  @override
  Future<void> announce(SplitAlert alert) async => alerts.add(alert);
}

/// Phát lại sẵn một danh sách điểm, không chờ thời gian thật.
class _FakeLocationService implements LocationService {
  _FakeLocationService(this.fixes);

  final List<RawFix> fixes;

  @override
  Future<LocationAccess> ensurePermission({bool requestAlways = false}) async =>
      LocationAccess.always;

  @override
  Future<RawFix?> currentFix() async => fixes.isEmpty
      ? null
      // Dời mốc về "bây giờ" giống watch(): GPS thật luôn trả mốc hiện tại,
      // và điểm mồi đứng ngay trước dòng vị trí trong cùng một buổi ghi.
      : RawFix(
          lat: fixes.first.lat,
          lon: fixes.first.lon,
          timestamp: DateTime.now().toUtc(),
          accuracyM: fixes.first.accuracyM,
          elevationM: fixes.first.elevationM,
        );

  @override
  Stream<RawFix> watch(ActivityMode mode) async* {
    if (fixes.isEmpty) return;
    // Dời mốc về "bây giờ", giữ nguyên khoảng cách giữa các điểm — giống hệt
    // cách `GpxReplayLocationService` làm, và giống GPS thật ở chỗ mốc thời
    // gian luôn quanh giờ hiện tại.
    final anchor = DateTime.now().toUtc();
    final t0 = fixes.first.timestamp;
    for (final fix in fixes) {
      yield RawFix(
        lat: fix.lat,
        lon: fix.lon,
        timestamp: anchor.add(fix.timestamp.difference(t0)),
        accuracyM: fix.accuracyM,
        elevationM: fix.elevationM,
        speedMps: fix.speedMps,
      );
      // Nhường một vòng event loop để cubit kịp xử lý từng điểm.
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// Đứng yên: có vị trí nhưng `watch` không phát điểm nào, đúng như geolocator
/// khi quãng đường chưa vượt `distanceFilter`.
class _SilentStreamLocationService implements LocationService {
  @override
  Future<LocationAccess> ensurePermission({bool requestAlways = false}) async =>
      LocationAccess.always;

  @override
  Future<RawFix?> currentFix() async =>
      RawFix(lat: 16.073, lon: 108.247, timestamp: DateTime.now().toUtc(), accuracyM: 7);

  @override
  Stream<RawFix> watch(ActivityMode mode) => const Stream<RawFix>.empty();
}

/// Chờ tới khi [condition] đúng, tối đa [timeout]. Dùng thay cho `pumpEventQueue`
/// vì stream ở đây nhả điểm qua nhiều vòng event loop.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Hết $timeout mà điều kiện vẫn chưa đúng');
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}
