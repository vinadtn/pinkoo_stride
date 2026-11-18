import '../../activity/domain/entities/activity.dart';
import '../../activity/domain/entities/track_point.dart';
import '../../activity_mode/domain/activity_mode.dart';

/// Ném ra khi gói sao lưu sai cấu trúc hoặc hỏng.
///
/// Có kiểu riêng để tầng UI phân biệt được "file không đọc được" với lỗi hệ
/// thống, rồi hiện đúng câu cho người dùng thay vì một stack trace.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Chuyển hoạt động qua lại giữa entity và JSON của file sao lưu.
///
/// Giữ đủ mọi thứ người dùng tự nhập (tên, ghi chú) và mọi số liệu đã tính —
/// khôi phục xong phải ra đúng bản cũ, không phải tính lại rồi lệch vài mét.
abstract final class BackupCodec {
  static Map<String, Object?> activityToJson(Activity a) => {
    'mode': a.mode.id,
    'title': a.title,
    'startedAt': a.startedAt.toUtc().toIso8601String(),
    if (a.endedAt != null) 'endedAt': a.endedAt!.toUtc().toIso8601String(),
    'elapsedSec': a.elapsedSec,
    'movingSec': a.movingSec,
    'distanceM': a.distanceM,
    'pointCount': a.pointCount,
    if (a.calories != null) 'calories': a.calories,
    if (a.elevationGainM != null) 'elevationGainM': a.elevationGainM,
    if (a.placeLabel != null) 'placeLabel': a.placeLabel,
    if (a.note != null) 'note': a.note,
    'points': [for (final p in a.points) _pointToJson(p)],
  };

  static Activity activityFromJson(Map<String, Object?> json) {
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    if (startedAt == null) {
      throw const BackupFormatException('Một hoạt động thiếu mốc thời gian bắt đầu');
    }

    final rawPoints = json['points'];
    if (rawPoints != null && rawPoints is! List) {
      throw const BackupFormatException('Danh sách điểm GPS sai cấu trúc');
    }

    return Activity(
      // id của file không dùng tới: máy đích tự cấp id mới khi chèn.
      id: 0,
      mode: ActivityMode.fromId(json['mode'] as String? ?? 'run'),
      title: (json['title'] as String?)?.trim().isNotEmpty ?? false
          ? json['title']! as String
          : 'Hoạt động đã khôi phục',
      startedAt: startedAt,
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? ''),
      elapsedSec: _int(json['elapsedSec']),
      movingSec: _int(json['movingSec']),
      distanceM: _double(json['distanceM']),
      pointCount: _int(json['pointCount']),
      calories: _doubleOrNull(json['calories']),
      elevationGainM: _doubleOrNull(json['elevationGainM']),
      placeLabel: json['placeLabel'] as String?,
      note: json['note'] as String?,
      points: [
        for (final p in (rawPoints as List? ?? const []))
          _pointFromJson(p as Map<String, Object?>),
      ],
    );
  }

  static Map<String, Object?> _pointToJson(TrackPoint p) => {
    'lat': p.lat,
    'lon': p.lon,
    'tSec': p.tSec,
    'cumulativeM': p.cumulativeM,
    if (p.elevationM != null) 'ele': p.elevationM,
    if (p.accuracyM != null) 'acc': p.accuracyM,
    if (p.speedMps != null) 'spd': p.speedMps,
  };

  static TrackPoint _pointFromJson(Map<String, Object?> json) => TrackPoint(
    lat: _double(json['lat']),
    lon: _double(json['lon']),
    tSec: _double(json['tSec']),
    cumulativeM: _double(json['cumulativeM']),
    elevationM: _doubleOrNull(json['ele']),
    accuracyM: _doubleOrNull(json['acc']),
    speedMps: _doubleOrNull(json['spd']),
  );

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;
  static double _double(Object? v) => (v as num?)?.toDouble() ?? 0;
  static double? _doubleOrNull(Object? v) => (v as num?)?.toDouble();

  /// Đọc danh sách hoạt động từ nội dung `activities.json` đã parse.
  static List<Activity> activitiesFromJson(Object? decoded) {
    if (decoded is! List) {
      throw const BackupFormatException('activities.json phải là một danh sách');
    }
    return [
      for (final item in decoded)
        if (item is Map<String, Object?>)
          activityFromJson(item)
        else
          throw const BackupFormatException('Một phần tử trong activities.json sai kiểu'),
    ];
  }
}
