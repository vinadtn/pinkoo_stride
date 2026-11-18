import 'package:flutter/services.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/format/stat_format.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/split_alert.dart';

/// Rung một nhịp dài rồi n nhịp ngắn theo số chặng (tối đa 5).
///
/// Đếm được bằng tay nên biết đang ở chặng mấy mà không phải rút máy ra — thứ
/// duy nhất còn cảm nhận được khi đang bơi hoặc máy nằm trong túi.
class HapticSplitAnnouncer implements SplitAnnouncer {
  const HapticSplitAnnouncer();

  @override
  Future<void> announce(SplitAlert alert) async {
    await HapticFeedback.heavyImpact();
    final beats = alert.index.clamp(1, 5);
    for (var i = 0; i < beats; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      await HapticFeedback.mediumImpact();
    }
  }
}

/// Đọc thành tiếng, ví dụ "Đã 2 ki lô mét. Pace 5:50 trên ki lô mét".
///
/// Gọi thẳng `TextToSpeech` của Android qua [SpeechPlugin.channel] thay vì dùng
/// `flutter_tts`: thư viện đó vẫn `apply plugin: 'kotlin-android'`, mà AGP 9 đã
/// bỏ plugin đó nên thêm vào là cả app không build được.
class VoiceSplitAnnouncer implements SplitAnnouncer {
  const VoiceSplitAnnouncer(this._logger, [this._channel = _defaultChannel]);

  static const _defaultChannel = MethodChannel('pinkoo_stride/speech');

  final MethodChannel _channel;
  final AppLogger _logger;

  @override
  Future<void> announce(SplitAlert alert) async {
    try {
      await _channel.invokeMethod<bool>('speak', {'text': sentenceFor(alert)});
    } on Object catch (e) {
      // Máy thiếu bộ đọc, hoặc đang chạy trên nền tảng chưa cài đặt kênh này —
      // mất câu nói chứ không được làm hỏng buổi ghi.
      _logger.w('Không đọc được báo chặng: $e');
    }
  }

  /// Câu đọc cho một chặng. Tách riêng để test được mà không cần máy thật.
  static String sentenceFor(SplitAlert alert) {
    final pace = StatFormat.duration(alert.paceSecPerUnit);
    if (alert.mode.splitsIn100m) {
      return 'Đã ${alert.index} trăm mét. Pace $pace trên 100 mét.';
    }
    return 'Đã ${alert.index} ki lô mét. Pace $pace trên ki lô mét.';
  }
}

/// Chọn cách báo theo cài đặt, đọc lại mỗi lần báo.
///
/// Đọc lại từng lần thay vì nhớ sẵn: người dùng đổi cài đặt giữa buổi tập là ăn
/// ngay, không phải dừng rồi ghi lại mới có tác dụng.
class SplitAnnouncerRouter implements SplitAnnouncer {
  SplitAnnouncerRouter(this._storage, this._voice);

  final LocalStorage _storage;
  final SplitAnnouncer _voice;

  static const _haptic = HapticSplitAnnouncer();

  SplitAlertMode get mode =>
      SplitAlertMode.fromId(_storage.getString(StorageKeys.splitAlertMode));

  @override
  Future<void> announce(SplitAlert alert) => switch (mode) {
    SplitAlertMode.off => Future<void>.value(),
    SplitAlertMode.haptic => _haptic.announce(alert),
    SplitAlertMode.voice => _voice.announce(alert),
  };
}
