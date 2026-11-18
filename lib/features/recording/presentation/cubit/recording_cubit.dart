import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/geo/auto_pause.dart';
import '../../../../core/geo/simplify_route.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../activity/domain/entities/track_point.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/domain/calorie_estimate.dart';
import '../../data/foreground_location_service.dart';
import '../../data/location_service.dart';
import '../../domain/raw_fix.dart';
import '../../domain/split_alert.dart';
import '../../domain/track_accumulator.dart';
import 'recording_state.dart';

/// Điều khiển một buổi ghi: xin quyền → nhận GPS → cộng dồn → autosave → lưu.
///
/// Hai thứ đáng chú ý:
/// - **Ghi vào DB ngay từ đầu**, không giữ hết trong RAM: app bị kill giữa buổi
///   thì mở lại vẫn phục hồi được.
/// - **Đồng hồ chạy bằng timer riêng**, không chờ GPS: đứng chờ đèn đỏ mà số
///   giây đứng im thì người dùng tưởng app treo.
class RecordingCubit extends Cubit<RecordingState> {
  RecordingCubit({
    required this.location,
    required this.repository,
    required this.storage,
    required this.logger,
    this.splitAnnouncer = const SilentSplitAnnouncer(),
    ActivityMode? initialMode,
  }) : super(
         RecordingState(
           mode:
               initialMode ??
               ActivityMode.fromId(storage.getString(StorageKeys.lastActivityMode) ?? 'run'),
         ),
       );

  final LocationService location;
  final ActivityRepository repository;
  final LocalStorage storage;
  final AppLogger logger;

  /// Báo mỗi khi xong một chặng. Mặc định im lặng — người dùng tự bật trong
  /// Cài đặt, và test không phải rung hay nói gì.
  final SplitAnnouncer splitAnnouncer;

  TrackAccumulator? _accumulator;
  StreamSubscription<RawFix>? _fixes;
  Timer? _ticker;
  Timer? _autosave;

  /// Số điểm đã ghi xuống DB — các điểm sau mốc này là phần chờ flush.
  int _flushedCount = 0;

  /// Đã nhận được lần định vị đầu tiên của buổi này chưa.
  bool _primed = false;

  /// Mốc thời gian của điểm GPS cuối nhận được — ghi lại mỗi lần autosave để
  /// lần sau biết nhật ký của service có gì chưa vào DB.
  DateTime? _lastFixAt;

  /// Chặng cuối đã báo. Đặt lại mỗi buổi, và nhảy thẳng tới chặng hiện tại khi
  /// phục hồi buổi dở — không thì mở lại app là báo dồn một tràng.
  int _lastAnnouncedSplit = 0;

  /// Theo dõi auto-pause — CHỈ để ghi log.
  ///
  /// Cố ý không gọi `pause()` và không đụng vào `TrackAccumulator`: buổi tập
  /// phải ghi ra y hệt như khi chưa có tính năng này. Việc tính lại số liệu
  /// "nếu có auto-pause" nằm ở màn lịch sử, trên dữ liệu đã lưu.
  AutoPauseWatcher? _pauseWatcher;

  /// Mỗi [_autosaveEvery] giây lại ghi điểm mới + số liệu tổng xuống DB.
  /// 10 s: mất nhiều nhất 10 s dữ liệu nếu app chết, mà không ghi đĩa liên tục.
  static const _autosaveEvery = Duration(seconds: 10);

  /// Dồn đủ chừng này điểm chưa ghi thì flush luôn, không đợi hết 10 s.
  ///
  /// Chỉ dựa vào đồng hồ là chưa đủ: app chết trong 10 giây đầu thì bản ghi
  /// rỗng và buổi tập mất trắng. Mốc theo số điểm chặn luôn trường hợp đó, và
  /// cũng chặn trường hợp ngược lại — đạp xe nhanh, 10 s là vài trăm mét.
  static const _flushEveryPoints = 25;

  /// Nối các lần flush thành một dây tuần tự.
  ///
  /// Timer 10 s, mốc 25 điểm và cả lúc bấm Dừng đều gọi flush; chạy chồng nhau
  /// thì hai lần cùng đọc `_flushedCount` cũ và ghi trùng điểm vào DB.
  Future<void> _flushQueue = Future<void>.value();

  /// Vẽ đường bằng điểm đã rút gọn. 2 m là mức mắt thường không thấy khác, mà
  /// bản đồ đỡ phải vẽ hàng nghìn đoạn mỗi giây.
  static const _drawToleranceM = 2.0;

  double get _weightKg => storage.getDouble(StorageKeys.weightKg) ?? defaultWeightKg;

  // ------------------------------------------------------------ chọn chế độ --

  void selectMode(ActivityMode mode) {
    if (state.isLive) return; // đang ghi thì không cho đổi chế độ giữa buổi
    storage.setString(StorageKeys.lastActivityMode, mode.id);
    emit(state.copyWith(mode: mode, status: RecordingStatus.idle));
  }

  // --------------------------------------------------------------- phục hồi --

  /// Tìm buổi ghi còn treo từ lần chạy trước. Gọi khi mở màn ghi.
  Future<void> checkUnfinished() async {
    final found = await repository.findUnfinished();
    if (found == null || found.points.isEmpty) {
      // Bản ghi rỗng (bấm Bắt đầu rồi tắt app ngay) thì dọn luôn, đừng hỏi.
      if (found != null) await repository.delete(found.id);
      return;
    }
    emit(state.copyWith(unfinished: found, mode: found.mode));
  }

  /// Ghi tiếp buổi còn treo.
  Future<void> continueUnfinished() async {
    final found = state.unfinished;
    if (found == null) return;

    final access = await location.ensurePermission(requestAlways: true);
    if (!access.canRecord) {
      emit(state.copyWith(status: RecordingStatus.blocked, access: access));
      return;
    }

    final acc = TrackAccumulator(mode: found.mode)
      ..restore(
        startedAt: found.startedAt,
        resumedAt: DateTime.now(),
        points: found.points,
        movingSec: found.movingSec.toDouble(),
        elevationGainM: found.elevationGainM ?? 0,
      );
    _accumulator = acc;
    _flushedCount = found.points.length;
    await _drainServiceFixes(acc);

    emit(
      state.copyWith(
        status: RecordingStatus.recording,
        access: access,
        mode: found.mode,
        activityId: found.id,
        clearUnfinished: true,
      ),
    );
    _pushTotals();
    _listen(found.mode);
  }

  /// Lưu luôn buổi còn treo mà không ghi thêm.
  Future<void> saveUnfinished() async {
    final found = state.unfinished;
    if (found == null) return;
    emit(state.copyWith(status: RecordingStatus.saving, clearUnfinished: true));
    await repository.finishRecording(
      found.id,
      endedAt: found.startedAt.add(Duration(seconds: found.elapsedSec)),
      totals: ActivityTotals(
        elapsedSec: found.elapsedSec,
        movingSec: found.movingSec,
        distanceM: found.distanceM,
        pointCount: found.pointCount,
        elevationGainM: found.elevationGainM,
        calories: estimateCalories(
          mode: found.mode,
          seconds: found.elapsedSec,
          weightKg: _weightKg,
        ),
      ),
    );
    emit(state.copyWith(status: RecordingStatus.saved, savedActivityId: found.id));
  }

  Future<void> discardUnfinished() async {
    final found = state.unfinished;
    if (found == null) return;
    await repository.delete(found.id);
    emit(state.copyWith(clearUnfinished: true, status: RecordingStatus.idle));
  }

  // ------------------------------------------------------------------- ghi --

  /// Xin quyền trước khi bấm Bắt đầu, để màn hình kịp hiện bản đồ đúng vị trí.
  Future<void> prepare() async {
    emit(state.copyWith(status: RecordingStatus.preparing));
    final access = await location.ensurePermission();
    emit(
      state.copyWith(
        status: access.canRecord ? RecordingStatus.idle : RecordingStatus.blocked,
        access: access,
      ),
    );
  }

  Future<void> start() async {
    if (state.isLive) return;

    emit(state.copyWith(status: RecordingStatus.preparing));
    final access = await location.ensurePermission(requestAlways: true);
    if (!access.canRecord) {
      emit(state.copyWith(status: RecordingStatus.blocked, access: access));
      return;
    }

    final mode = state.mode;
    final startedAt = DateTime.now();
    final id = await repository.startRecording(
      mode: mode,
      title: defaultActivityTitle(mode: mode, at: startedAt),
      startedAt: startedAt,
    );

    // Cùng mốc thời gian với bản ghi trong DB, để đồng hồ chạy ngay từ lúc bấm
    // Bắt đầu chứ không đợi GPS bắt được sóng.
    _accumulator = TrackAccumulator(mode: mode, startedAt: startedAt);
    _flushedCount = 0;

    // State mới hẳn, không copyWith: mọi số liệu của buổi trước phải về 0.
    emit(
      RecordingState(
        mode: mode,
        status: RecordingStatus.recording,
        access: access,
        activityId: id,
      ),
    );
    _listen(mode);
  }

  void pause() {
    final acc = _accumulator;
    if (acc == null || state.status != RecordingStatus.recording) return;
    acc.pause(DateTime.now());
    emit(state.copyWith(status: RecordingStatus.paused));
  }

  void resume() {
    final acc = _accumulator;
    if (acc == null || state.status != RecordingStatus.paused) return;
    acc.resume(DateTime.now());
    emit(state.copyWith(status: RecordingStatus.recording));
  }

  /// Dừng và lưu. Dưới [ActivityMode.minDistanceToSaveM] mét thì bỏ, không lưu
  /// rác vào lịch sử.
  Future<void> finish() async {
    final acc = _accumulator;
    final id = state.activityId;
    if (acc == null || id == null) return;

    await _stopStreams();
    emit(state.copyWith(status: RecordingStatus.saving));

    if (acc.distanceM < ActivityMode.minDistanceToSaveM) {
      await repository.delete(id);
      _accumulator = null;
      emit(state.copyWith(status: RecordingStatus.tooShort, activityId: null));
      return;
    }

    await _flushPoints(acc);
    final elapsed = acc.elapsedSecAt(DateTime.now());
    await repository.finishRecording(
      id,
      endedAt: DateTime.now(),
      totals: ActivityTotals(
        elapsedSec: elapsed.round(),
        movingSec: acc.movingSec.round(),
        distanceM: acc.distanceM,
        pointCount: acc.pointCount,
        elevationGainM: acc.elevationGainM,
        calories: estimateCalories(mode: acc.mode, seconds: elapsed, weightKg: _weightKg),
      ),
    );

    logger.i(
      'Đã lưu hoạt động #$id: ${acc.distanceM.toStringAsFixed(0)} m, '
      '${acc.pointCount} điểm, bỏ ${acc.rejections}',
    );
    _accumulator = null;
    emit(state.copyWith(status: RecordingStatus.saved, savedActivityId: id));
  }

  Future<void> discard() async {
    final id = state.activityId;
    await _stopStreams();
    if (id != null) await repository.delete(id);
    _accumulator = null;
    emit(RecordingState(mode: state.mode, status: RecordingStatus.discarded));
  }

  /// Về trạng thái ban đầu sau khi màn hình đã xử lý xong `saved`/`tooShort`.
  void reset() => emit(RecordingState(mode: state.mode));

  // ------------------------------------------------------------- nội bộ --

  void _listen(ActivityMode mode) {
    _primed = false;
    _lastAnnouncedSplit =
        (_accumulator?.distanceM ?? 0) ~/ mode.splitDistanceM;
    _pauseWatcher = mode.autoPauseWatcher();
    _fixes = location.watch(mode).listen(
      _onFix,
      onError: (Object e, StackTrace s) =>
          logger.e('Lỗi dòng vị trí', error: e, stackTrace: s),
      cancelOnError: false,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _autosave = Timer.periodic(_autosaveEvery, (_) => _onAutosave());
    unawaited(_primeFirstFix());
  }

  /// Lấy ngay một lần định vị thay vì ngồi đợi dòng vị trí.
  ///
  /// `getPositionStream` chạy với `distanceFilter` theo chế độ (3–10 m), nên khi
  /// đứng yên chờ xuất phát nó KHÔNG phát điểm nào — không có điểm thì
  /// `lastAccuracyM` còn null và chip GPS đứng mãi ở "Đang tìm tín hiệu GPS…".
  /// Bản đồ vẫn vẽ được chấm xanh vì Mapbox tự lấy vị trí riêng, không đi qua
  /// dòng này, nên nhìn vào là tưởng app hỏng.
  Future<void> _primeFirstFix() async {
    if (_primed) return;
    final fix = await location.currentFix();
    // Trong lúc chờ: dòng vị trí đã kịp phát điểm, hoặc buổi ghi đã dừng.
    if (fix == null || _primed || _accumulator == null) return;
    _onFix(fix);
  }

  void _onFix(RawFix fix) {
    final acc = _accumulator;
    if (acc == null) return;
    _primed = true;
    _lastFixAt = fix.timestamp;
    final countBefore = acc.pointCount;
    acc.add(fix);
    // Điểm bị bộ lọc bỏ thì cũng không đưa vào bộ theo dõi auto-pause, để lúc
    // ghi và lúc xem lại cùng nhìn một dãy điểm như nhau.
    if (acc.pointCount > countBefore) {
      _logAutoPause(acc.points.last);
      _announceSplitIfDue(acc);
    }
    _pushTotals(lastAccuracyM: fix.accuracyM);
    if (acc.pointCount - _flushedCount >= _flushEveryPoints) {
      unawaited(_onAutosave());
    }
  }

  /// Nạp các điểm foreground service đã ghi trong lúc isolate chính không sống.
  ///
  /// Service vừa gửi điểm sang đây vừa ghi ra file, nên phần app còn sống đã vào
  /// DB rồi. Lọc theo mốc đã lưu để chỉ lấy phần SAU đó — không thì khôi phục
  /// xong là quãng đường bị cộng đôi.
  Future<void> _drainServiceFixes(TrackAccumulator acc) async {
    final service = location;
    if (service is! ForegroundLocationService) return;

    final fixes = await service.drainPendingFixes();
    if (fixes.isEmpty) return;

    final since = DateTime.tryParse(
      storage.getString(StorageKeys.lastPersistedFixAt) ?? '',
    );
    var taken = 0;
    for (final fix in fixes) {
      if (since != null && !fix.timestamp.isAfter(since)) continue;
      acc.add(fix);
      taken++;
    }
    if (taken > 0) {
      _lastFixAt = fixes.last.timestamp;
      logger.i('Nạp thêm $taken điểm service ghi lúc app đã tắt');
      await _flushPoints(acc);
    }
  }

  /// Báo khi vừa vượt một mốc chặng (1 km, hoặc 100 m khi bơi).
  void _announceSplitIfDue(TrackAccumulator acc) {
    // Đang tạm dừng thủ công thì im — người dùng đang nghỉ, không phải vừa xong chặng.
    if (state.status != RecordingStatus.recording) return;

    final splitIndex = acc.distanceM ~/ acc.mode.splitDistanceM;
    if (splitIndex <= _lastAnnouncedSplit) return;
    _lastAnnouncedSplit = splitIndex;

    final elapsed = acc.elapsedSecAt(DateTime.now());
    final unitM = acc.mode.splitsIn100m ? 100 : 1000;
    final pace = acc.distanceM <= 0 ? 0.0 : elapsed / (acc.distanceM / unitM);

    unawaited(
      splitAnnouncer.announce(
        SplitAlert(
          index: splitIndex,
          mode: acc.mode,
          distanceM: acc.distanceM,
          paceSecPerUnit: pace,
        ),
      ),
    );
  }

  /// Ghi log mỗi lần auto-pause đổi nhận định. Không đổi gì trong bản ghi.
  void _logAutoPause(TrackPoint point) {
    final watcher = _pauseWatcher;
    if (watcher == null) return;

    final wasStopped = watcher.isStopped;
    final closed = watcher.add(point);

    if (!wasStopped && watcher.isStopped) {
      logger.i(
        'Auto-pause: coi như đã dừng từ giây ${watcher.openInterval!.fromSec.round()} '
        '(${point.cumulativeM.toStringAsFixed(0)} m)',
      );
    } else if (closed != null) {
      logger.i(
        'Auto-pause: đi tiếp ở giây ${point.tSec.round()} — '
        'khoảng dừng dài ${closed.durationSec.round()} s',
      );
    }
  }

  /// Nhịp mỗi giây: đồng hồ và calo phải nhảy kể cả khi GPS im.
  void _onTick() {
    final acc = _accumulator;
    if (acc == null || state.status != RecordingStatus.recording) return;
    _pushTotals();
  }

  void _pushTotals({double? lastAccuracyM}) {
    final acc = _accumulator;
    if (acc == null) return;
    final elapsed = acc.elapsedSecAt(DateTime.now());
    emit(
      state.copyWith(
        distanceM: acc.distanceM,
        elapsedSec: elapsed,
        movingSec: acc.movingSec,
        pointCount: acc.pointCount,
        routeForDrawing: simplifyRoute(acc.points, toleranceM: _drawToleranceM),
        lastPoint: acc.points.isEmpty ? null : acc.points.last,
        currentSpeedMps: acc.currentSpeedMps,
        lastAccuracyM: lastAccuracyM,
        calories: estimateCalories(mode: acc.mode, seconds: elapsed, weightKg: _weightKg),
      ),
    );
  }

  Future<void> _onAutosave() async {
    final acc = _accumulator;
    final id = state.activityId;
    if (acc == null || id == null) return;
    try {
      await _flushPoints(acc);
      final at = _lastFixAt;
      if (at != null) {
        await storage.setString(
          StorageKeys.lastPersistedFixAt,
          at.toUtc().toIso8601String(),
        );
      }
      await repository.saveProgress(
        id,
        ActivityTotals(
          elapsedSec: acc.elapsedSecAt(DateTime.now()).round(),
          movingSec: acc.movingSec.round(),
          distanceM: acc.distanceM,
          pointCount: acc.pointCount,
          elevationGainM: acc.elevationGainM,
        ),
      );
    } on Exception catch (e, s) {
      // Autosave lỗi thì buổi ghi vẫn phải chạy tiếp — dữ liệu còn trong RAM.
      logger.w('Autosave thất bại', error: e, stackTrace: s);
    }
  }

  /// Ghi các điểm chưa lưu xuống DB, tuần tự với mọi lần flush khác.
  Future<void> _flushPoints(TrackAccumulator acc) {
    // Lỗi của lần trước không được làm chết dây: bắt tại chỗ rồi đi tiếp.
    final next = _flushQueue
        .then((_) => _appendPending(acc))
        .catchError((Object e, StackTrace s) {
          logger.w('Ghi điểm xuống DB thất bại', error: e, stackTrace: s);
        });
    _flushQueue = next;
    return next;
  }

  Future<void> _appendPending(TrackAccumulator acc) async {
    final id = state.activityId;
    if (id == null) return;
    final points = acc.points;
    if (points.length <= _flushedCount) return;
    final pending = List<TrackPoint>.of(points.sublist(_flushedCount));
    await repository.appendPoints(id, pending);
    _flushedCount += pending.length;
  }

  Future<void> _stopStreams() async {
    _pauseWatcher = null;
    _ticker?.cancel();
    _autosave?.cancel();
    _ticker = null;
    _autosave = null;
    await _fixes?.cancel();
    _fixes = null;
  }

  @override
  Future<void> close() async {
    await _stopStreams();
    // Thoát khi vẫn đang ghi (người dùng bấm back, hoặc hệ thống dọn màn): ghi
    // nốt phần điểm còn treo để lần sau phục hồi được đúng tới chỗ cuối.
    final acc = _accumulator;
    if (acc != null) await _flushPoints(acc);
    return super.close();
  }
}

/// Tên mặc định kiểu "Buổi chạy chiều" — người dùng sửa lại được sau.
String defaultActivityTitle({required ActivityMode mode, required DateTime at}) {
  final what = switch (mode) {
    ActivityMode.run => 'Buổi chạy',
    ActivityMode.walk => 'Buổi đi bộ',
    ActivityMode.swim => 'Buổi bơi',
    ActivityMode.ride => 'Buổi đạp xe',
  };
  final when = switch (at.hour) {
    < 11 => 'sáng',
    < 13 => 'trưa',
    < 18 => 'chiều',
    _ => 'tối',
  };
  return '$what $when';
}
