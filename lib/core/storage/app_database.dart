import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'app_database.g.dart';

/// Trạng thái của một bản ghi hoạt động.
enum ActivityStatus {
  /// Đang ghi. Có đúng một dòng ở trạng thái này tại một thời điểm; nếu app
  /// bị kill thì lần mở sau tìm thấy nó để hỏi người dùng phục hồi.
  recording,

  /// Đã dừng và lưu xong.
  done,
}

/// Một buổi vận động. Mọi số liệu tổng được lưu sẵn để màn danh sách không
/// phải đọc hàng nghìn track point chỉ để vẽ một thẻ.
///
/// Tên lớp dòng là `ActivityRow` để không đụng entity `Activity` của domain.
@DataClassName('ActivityRow')
class Activities extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `ActivityMode.id` — lưu chuỗi để thêm chế độ mới không làm sai dữ liệu cũ.
  TextColumn get mode => text().withLength(min: 1, max: 16)();

  TextColumn get status =>
      textEnum<ActivityStatus>().withDefault(const Constant('done'))();

  TextColumn get title => text().withLength(max: 200)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  IntColumn get elapsedSec => integer().withDefault(const Constant(0))();
  IntColumn get movingSec => integer().withDefault(const Constant(0))();
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  IntColumn get pointCount => integer().withDefault(const Constant(0))();

  RealColumn get calories => real().nullable()();
  RealColumn get elevationGainM => real().nullable()();
  TextColumn get placeLabel => text().nullable()();
  TextColumn get note => text().nullable()();
}

/// Điểm GPS đã lọc. Ghi trực tiếp vào đây ngay trong lúc ghi (không giữ hết
/// trong RAM rồi mới lưu), nên app bị kill giữa buổi vẫn còn dữ liệu.
@DataClassName('TrackPointRow')
@TableIndex(name: 'idx_track_points_activity', columns: {#activityId, #tSec})
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get activityId =>
      integer().references(Activities, #id, onDelete: KeyAction.cascade)();

  RealColumn get lat => real()();
  RealColumn get lon => real()();

  /// Giây kể từ điểm đầu, đã trừ thời gian tạm dừng.
  RealColumn get tSec => real()();

  RealColumn get cumulativeM => real()();
  RealColumn get elevationM => real().nullable()();
  RealColumn get accuracyM => real().nullable()();
  RealColumn get speedMps => real().nullable()();
}

@DriftDatabase(tables: [Activities, TrackPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// Dùng trong test: DB trong RAM, không chạm đĩa.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // ON DELETE CASCADE của track_points chỉ có tác dụng khi bật foreign keys —
      // SQLite tắt mặc định, và phải bật lại ở MỖI kết nối.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _open() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'pinkoo_stride.sqlite'));
      // sqlite3 cần chỗ ghi file tạm, mặc định trên Android không có.
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
      return NativeDatabase.createInBackground(file);
    });
  }
}
