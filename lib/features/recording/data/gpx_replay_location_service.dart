import 'dart:async';

import 'package:flutter/services.dart' show AssetBundle;

import '../../../core/geo/gpx.dart';
import '../../activity_mode/domain/activity_mode.dart';
import '../domain/raw_fix.dart';
import 'location_service.dart';

/// Nguồn vị trí GIẢ: phát lại một file GPX có sẵn thành stream như GPS thật.
///
/// Để kiểm thử luồng ghi trên máy thật mà không phải ra đường (và tuyệt đối
/// không cần browser): chạy app với `--dart-define=REPLAY_GPX=true`, bấm Bắt
/// đầu, rồi đối chiếu số liệu cuối với mốc đã biết của `Afternoon_Swim.gpx`
/// (2.116,1 m sau khi lọc — xem `test/features/recording/track_accumulator_test.dart`).
///
/// Mốc thời gian phát ra là **giờ gốc trong file**, không phải giờ hiện tại:
/// nhờ vậy quãng đường và pace tính ra đúng bằng bản tính offline, dù đang phát
/// nhanh gấp [speedUp] lần.
class GpxReplayLocationService implements LocationService {
  GpxReplayLocationService({
    required this.bundle,
    this.assetPath = 'assets/data/Afternoon_Swim.gpx',
    this.speedUp = 50,
  });

  final AssetBundle bundle;
  final String assetPath;

  /// Phát nhanh bao nhiêu lần so với thời gian thật.
  final double speedUp;

  Future<List<GpxPoint>> _load() async =>
      Gpx.decode(await bundle.loadString(assetPath)).points;

  @override
  Future<LocationAccess> ensurePermission({bool requestAlways = false}) async =>
      LocationAccess.always;

  @override
  Future<RawFix?> currentFix() async {
    final points = await _load();
    final p = points.first;
    return RawFix(
      lat: p.lat,
      lon: p.lon,
      // Mốc "bây giờ" chứ không phải giờ ghi trong file: `watch` cũng dời track
      // về hiện tại, và điểm mồi này đứng ngay trước nó trong cùng một buổi ghi
      // — lệch mốc là `tSec` của điểm đầu âm cả ngày.
      timestamp: DateTime.now().toUtc(),
      accuracyM: 5,
      elevationM: p.elevationM,
    );
  }

  @override
  Stream<RawFix> watch(ActivityMode mode) async* {
    final points = await _load();
    final t0 = points.first.time;
    // Dời mốc thời gian của cả track về "bây giờ" nhưng GIỮ NGUYÊN khoảng cách
    // giữa các điểm: giữ nguyên thì tốc độ từng đoạn vẫn thật (bộ lọc không bỏ
    // oan điểm nào), còn dời mốc thì `tSec` tính đúng so với lúc bấm Bắt đầu
    // thay vì âm cả ngày so với giờ máy.
    final anchor = DateTime.now().toUtc();

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i > 0 && p.time != null && points[i - 1].time != null) {
        final gap = p.time!.difference(points[i - 1].time!);
        final wait = Duration(microseconds: (gap.inMicroseconds / speedUp).round());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      yield RawFix(
        lat: p.lat,
        lon: p.lon,
        timestamp: (t0 == null || p.time == null)
            ? DateTime.now().toUtc()
            : anchor.add(p.time!.difference(t0)),
        accuracyM: 5,
        elevationM: p.elevationM,
      );
    }
  }
}
