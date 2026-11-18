import 'package:drift/drift.dart';

import '../../../../core/storage/app_database.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/repositories/activity_repository.dart';

/// Bản cài đặt [ActivityRepository] trên SQLite — nguồn dữ liệu duy nhất khi
/// chưa có backend.
class ActivityRepositoryLocal implements ActivityRepository {
  ActivityRepositoryLocal(this._db);

  final AppDatabase _db;

  @override
  Future<int> startRecording({
    required ActivityMode mode,
    required String title,
    required DateTime startedAt,
  }) async {
    // Chỉ được có một buổi đang ghi. Buổi cũ còn treo (app bị kill rồi người
    // dùng chọn bỏ) mà không dọn thì lần phục hồi sau sẽ nhặt nhầm buổi cũ.
    await _db.managers.activities
        .filter((f) => f.status.equals(ActivityStatus.recording))
        .delete();

    return _db.managers.activities.create(
      (o) => o(
        mode: mode.id,
        status: const Value(ActivityStatus.recording),
        title: title,
        startedAt: startedAt,
      ),
    );
  }

  @override
  Future<void> appendPoints(int activityId, List<TrackPoint> points) async {
    if (points.isEmpty) return;
    await _db.batch((b) {
      b.insertAll(_db.trackPoints, [
        for (final p in points)
          TrackPointsCompanion.insert(
            activityId: activityId,
            lat: p.lat,
            lon: p.lon,
            tSec: p.tSec,
            cumulativeM: p.cumulativeM,
            elevationM: Value(p.elevationM),
            accuracyM: Value(p.accuracyM),
            speedMps: Value(p.speedMps),
          ),
      ]);
    });
  }

  @override
  Future<void> saveProgress(int activityId, ActivityTotals totals) async {
    await (_db.update(_db.activities)..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        elapsedSec: Value(totals.elapsedSec),
        movingSec: Value(totals.movingSec),
        distanceM: Value(totals.distanceM),
        pointCount: Value(totals.pointCount),
        elevationGainM: Value(totals.elevationGainM),
        calories: Value(totals.calories),
      ),
    );
  }

  @override
  Future<void> finishRecording(
    int activityId, {
    required DateTime endedAt,
    required ActivityTotals totals,
    String? placeLabel,
  }) async {
    await (_db.update(_db.activities)..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        status: const Value(ActivityStatus.done),
        endedAt: Value(endedAt),
        elapsedSec: Value(totals.elapsedSec),
        movingSec: Value(totals.movingSec),
        distanceM: Value(totals.distanceM),
        pointCount: Value(totals.pointCount),
        elevationGainM: Value(totals.elevationGainM),
        calories: Value(totals.calories),
        placeLabel: Value(placeLabel),
      ),
    );
  }

  @override
  Future<Activity?> findUnfinished() async {
    final row = await (_db.select(_db.activities)
          ..where((t) => t.status.equalsValue(ActivityStatus.recording))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _toEntity(row, await _pointsOf(row.id));
  }

  @override
  Stream<List<Activity>> watchFinished() {
    final q = _db.select(_db.activities)
      ..where((t) => t.status.equalsValue(ActivityStatus.done))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return q.watch().map((rows) => rows.map((r) => _toEntity(r, const [])).toList());
  }

  @override
  Future<Activity?> byId(int id, {bool withPoints = true}) async {
    final row = await (_db.select(_db.activities)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _toEntity(row, withPoints ? await _pointsOf(id) : const []);
  }

  @override
  Future<void> delete(int id) async {
    // track_points tự xoá theo nhờ ON DELETE CASCADE (foreign_keys đã bật
    // trong AppDatabase.migration.beforeOpen).
    await (_db.delete(_db.activities)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> rename(int id, String title) async {
    await (_db.update(_db.activities)..where((t) => t.id.equals(id)))
        .write(ActivitiesCompanion(title: Value(title)));
  }

  @override
  Future<void> updateNote(int id, String? note) async {
    await (_db.update(_db.activities)..where((t) => t.id.equals(id)))
        .write(ActivitiesCompanion(note: Value(note)));
  }

  @override
  Future<List<Activity>> allForBackup() async {
    final rows =
        await (_db.select(_db.activities)
              ..where((t) => t.status.equalsValue(ActivityStatus.done))
              ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
            .get();
    return [
      for (final row in rows) _toEntity(row, await _pointsOf(row.id)),
    ];
  }

  @override
  Future<List<({String modeId, DateTime startedAt})>> finishedKeys() async {
    final rows =
        await (_db.select(_db.activities)
              ..where((t) => t.status.equalsValue(ActivityStatus.done)))
            .get();
    return [for (final row in rows) (modeId: row.mode, startedAt: row.startedAt)];
  }

  @override
  Future<int> importActivities(List<Activity> activities) async {
    if (activities.isEmpty) return 0;

    return _db.transaction(() async {
      var added = 0;
      for (final a in activities) {
        final id = await _db
            .into(_db.activities)
            .insert(
              ActivitiesCompanion.insert(
                // id của máy nguồn bị bỏ: máy này tự cấp id mới.
                mode: a.mode.id,
                status: const Value(ActivityStatus.done),
                title: a.title,
                startedAt: a.startedAt,
                endedAt: Value(a.endedAt),
                elapsedSec: Value(a.elapsedSec),
                movingSec: Value(a.movingSec),
                distanceM: Value(a.distanceM),
                pointCount: Value(a.pointCount),
                calories: Value(a.calories),
                elevationGainM: Value(a.elevationGainM),
                placeLabel: Value(a.placeLabel),
                note: Value(a.note),
              ),
            );
        await appendPoints(id, a.points);
        added++;
      }
      return added;
    });
  }

  Future<List<TrackPoint>> _pointsOf(int activityId) async {
    final rows = await (_db.select(_db.trackPoints)
          ..where((t) => t.activityId.equals(activityId))
          ..orderBy([(t) => OrderingTerm.asc(t.tSec)]))
        .get();
    return [
      for (final r in rows)
        TrackPoint(
          lat: r.lat,
          lon: r.lon,
          tSec: r.tSec,
          cumulativeM: r.cumulativeM,
          elevationM: r.elevationM,
          accuracyM: r.accuracyM,
          speedMps: r.speedMps,
        ),
    ];
  }

  Activity _toEntity(ActivityRow row, List<TrackPoint> points) => Activity(
    id: row.id,
    mode: ActivityMode.fromId(row.mode),
    title: row.title,
    startedAt: row.startedAt,
    endedAt: row.endedAt,
    elapsedSec: row.elapsedSec,
    movingSec: row.movingSec,
    distanceM: row.distanceM,
    pointCount: row.pointCount,
    calories: row.calories,
    elevationGainM: row.elevationGainM,
    placeLabel: row.placeLabel,
    note: row.note,
    points: points,
  );
}
