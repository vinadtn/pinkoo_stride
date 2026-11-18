import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/logger/app_logger.dart';
import '../../activity_mode/domain/activity_mode.dart';
import '../domain/raw_fix.dart';
import 'location_service.dart';
import 'pending_fix_log.dart';
import 'recording_task_handler.dart';

/// Nguồn vị trí chạy trong foreground service có isolate riêng.
///
/// Khác [GeolocatorLocationService] ở đúng một điểm, nhưng là điểm quyết định:
/// luồng GPS nằm ở isolate của service, nên **vuốt app khỏi recents thì buổi ghi
/// vẫn chạy tiếp**. Isolate chính chỉ nhận lại điểm để vẽ và tính, chết lúc nào
/// cũng được.
///
/// Dựng service hỏng (máy lạ, người dùng chặn thông báo, Android đời cũ) thì tự
/// rơi về [fallback] — thà ghi được như cũ còn hơn không ghi được gì.
class ForegroundLocationService implements LocationService {
  ForegroundLocationService(this._fallback, this._logger, [this._log = const PendingFixLog()]);

  final LocationService _fallback;
  final AppLogger _logger;
  final PendingFixLog _log;

  /// Chỉ Android mới có foreground service kiểu này.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  bool _usingFallback = false;

  @override
  Future<LocationAccess> ensurePermission({bool requestAlways = false}) async {
    final access = await _fallback.ensurePermission(requestAlways: requestAlways);
    if (!access.canRecord || !isSupported) return access;

    // Android 13+ không có quyền này thì service chạy mà không ai thấy thông báo.
    if (!await FlutterForegroundTask.checkNotificationPermission().then(
      (p) => p == NotificationPermission.granted,
    )) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    return access;
  }

  @override
  Future<RawFix?> currentFix() => _fallback.currentFix();

  @override
  Stream<RawFix> watch(ActivityMode mode) {
    if (!isSupported) return _fallback.watch(mode);

    final controller = StreamController<RawFix>();
    var started = false;

    void onData(Object data) {
      if (data is! String) return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, Object?>) {
          controller.add(PendingFixLog.decode(decoded));
        }
      } on Object {
        // Gói tin hỏng — bỏ một điểm, không làm đứt cả dòng.
      }
    }

    controller
      ..onListen = () async {
        FlutterForegroundTask.addTaskDataCallback(onData);
        started = await _startService(mode);
        if (!started) {
          _usingFallback = true;
          _logger.w('Không dựng được foreground service — ghi bằng luồng thường');
          FlutterForegroundTask.removeTaskDataCallback(onData);
          await controller.addStream(_fallback.watch(mode));
        }
      }
      ..onCancel = () async {
        FlutterForegroundTask.removeTaskDataCallback(onData);
        if (started) await stop();
      };

    return controller.stream;
  }

  /// Đang phải chạy bằng đường dự phòng (không có service nền).
  bool get usingFallback => _usingFallback;

  Future<bool> _startService(ActivityMode mode) async {
    try {
      _initOnce();
      await RecordingTaskHandler.saveMode(mode);

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }

      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Pinkoo Stride đang ghi',
        notificationText: 'Đang theo dấu đường bạn đi — chạm để mở lại.',
        callback: recordingServiceEntryPoint,
      );
      return result is ServiceRequestSuccess;
    } on Object catch (e, s) {
      _logger.e('Dựng foreground service thất bại', error: e, stackTrace: s);
      return false;
    }
  }

  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } on Object catch (e) {
      _logger.w('Dừng foreground service thất bại: $e');
    }
  }

  /// Điểm GPS mà service đã ghi trong lúc isolate chính không còn sống.
  Future<List<RawFix>> drainPendingFixes() async {
    final fixes = await _log.readAll();
    if (fixes.isNotEmpty) {
      _logger.i('Nhặt lại ${fixes.length} điểm service ghi lúc app đã tắt');
    }
    await _log.clear();
    return fixes;
  }

  static bool _initialized = false;

  void _initOnce() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pinkoo_stride_recording',
        channelName: 'Ghi hoạt động',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        // Vuốt app khỏi recents mà service vẫn sống — cả tính năng này nằm ở đây.
        allowWakeLock: true,
      ),
    );
    _initialized = true;
  }
}
