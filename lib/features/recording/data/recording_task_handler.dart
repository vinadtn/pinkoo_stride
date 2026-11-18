import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../activity_mode/domain/activity_mode.dart';
import '../domain/raw_fix.dart';
import 'pending_fix_log.dart';

/// Điểm vào của isolate foreground service.
///
/// `@pragma('vm:entry-point')` là bắt buộc: hàm này được gọi từ Android chứ
/// không phải từ Dart, nên tree-shaking của bản release sẽ cắt mất nếu không có.
@pragma('vm:entry-point')
void recordingServiceEntryPoint() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

/// Chạy trong isolate RIÊNG của foreground service — đây là thứ sống sót khi
/// người dùng vuốt app khỏi recents.
///
/// Việc của nó rất hẹp, cố ý:
/// 1. nghe GPS,
/// 2. đẩy từng điểm sang isolate chính (khi isolate đó còn sống, để vẽ bản đồ),
/// 3. ghi điểm ra file [PendingFixLog] để không mất khi isolate chính đã chết.
///
/// Nó KHÔNG mở cơ sở dữ liệu và KHÔNG tính toán gì. Mọi thống kê vẫn do isolate
/// chính làm, trên cùng một `TrackAccumulator` như trước — nhờ vậy số liệu không
/// thể lệch giữa hai đường.
class RecordingTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positions;
  final _log = const PendingFixLog();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Isolate nền không tự đăng ký plugin — thiếu dòng này là geolocator và
    // path_provider đều không gọi được.
    DartPluginRegistrant.ensureInitialized();

    final mode = ActivityMode.fromId(
      await FlutterForegroundTask.getData<String>(key: _modeKey) ?? ActivityMode.run.id,
    );

    _positions = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: mode.gpsDistanceFilterM,
        intervalDuration: const Duration(seconds: 1),
      ),
    ).listen(_onPosition, onError: (Object _) {});
  }

  Future<void> _onPosition(Position p) async {
    final fix = RawFix(
      lat: p.latitude,
      lon: p.longitude,
      timestamp: p.timestamp,
      accuracyM: p.accuracy,
      elevationM: p.altitude,
      speedMps: p.speed,
    );

    // Ghi ra file TRƯỚC khi gửi: isolate chính có thể đã chết, file mới là chỗ
    // chắc chắn còn lại.
    await _log.append(fix);
    FlutterForegroundTask.sendDataToMain(jsonEncode(PendingFixLog.encode(fix)));
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positions?.cancel();
    _positions = null;
  }

  /// Khoá truyền chế độ sang isolate service (nó không đọc được state của app).
  static const _modeKey = 'recording_mode';

  static Future<void> saveMode(ActivityMode mode) =>
      FlutterForegroundTask.saveData(key: _modeKey, value: mode.id);
}
