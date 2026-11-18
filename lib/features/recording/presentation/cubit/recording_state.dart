import 'package:equatable/equatable.dart';

import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/track_point.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../data/location_service.dart';

enum RecordingStatus {
  /// Đã chọn chế độ, chưa bấm Bắt đầu.
  idle,

  /// Đang xin quyền / chờ GPS bắt được vị trí đầu tiên.
  preparing,

  /// Không ghi được: thiếu quyền hoặc dịch vụ vị trí tắt. Xem [RecordingState.access].
  blocked,

  recording,
  paused,

  /// Đang ghi nốt xuống DB.
  saving,

  /// Đã lưu xong — [RecordingState.savedActivityId] là id để mở màn chi tiết.
  saved,

  /// Quá ngắn nên không lưu.
  tooShort,

  /// Người dùng bỏ buổi này.
  discarded,
}

/// Chất lượng GPS, suy từ sai số của điểm gần nhất.
enum GpsQuality { unknown, weak, fair, good }

class RecordingState extends Equatable {
  const RecordingState({
    required this.mode,
    this.status = RecordingStatus.idle,
    this.access,
    this.activityId,
    this.savedActivityId,
    this.distanceM = 0,
    this.elapsedSec = 0,
    this.movingSec = 0,
    this.pointCount = 0,
    this.routeForDrawing = const [],
    this.lastPoint,
    this.currentSpeedMps,
    this.lastAccuracyM,
    this.calories = 0,
    this.unfinished,
  });

  final ActivityMode mode;
  final RecordingStatus status;

  /// Kết quả xin quyền gần nhất — UI dựa vào đây để hiện đúng lời nhắc.
  final LocationAccess? access;

  /// Id bản ghi đang mở trong DB (có ngay từ lúc bấm Bắt đầu).
  final int? activityId;

  final int? savedActivityId;

  final double distanceM;
  final double elapsedSec;
  final double movingSec;
  final int pointCount;

  /// Đường đã rút gọn để vẽ lên bản đồ — không phải toàn bộ điểm gốc.
  final List<TrackPoint> routeForDrawing;

  /// Điểm mới nhất, để đặt camera và marker mascot.
  final TrackPoint? lastPoint;

  final double? currentSpeedMps;
  final double? lastAccuracyM;
  final double calories;

  /// Buổi ghi còn treo từ lần chạy trước (app bị kill giữa buổi).
  final Activity? unfinished;

  bool get isLive => status == RecordingStatus.recording || status == RecordingStatus.paused;

  /// Pace hiện tại theo đơn vị của chế độ (giây/km hoặc giây/100m).
  double get paceSecPerUnit {
    if (distanceM <= 0 || elapsedSec <= 0) return 0;
    final unitM = mode.splitsIn100m ? 100 : 1000;
    return elapsedSec / (distanceM / unitM);
  }

  double get speedKmh => elapsedSec <= 0 ? 0 : (distanceM / 1000) / (elapsedSec / 3600);

  GpsQuality get gpsQuality {
    final acc = lastAccuracyM;
    if (acc == null) return GpsQuality.unknown;
    if (acc <= 8) return GpsQuality.good;
    if (acc <= mode.maxAccuracyM) return GpsQuality.fair;
    return GpsQuality.weak;
  }

  RecordingState copyWith({
    ActivityMode? mode,
    RecordingStatus? status,
    LocationAccess? access,
    int? activityId,
    int? savedActivityId,
    double? distanceM,
    double? elapsedSec,
    double? movingSec,
    int? pointCount,
    List<TrackPoint>? routeForDrawing,
    TrackPoint? lastPoint,
    double? currentSpeedMps,
    double? lastAccuracyM,
    double? calories,
    Activity? unfinished,
    bool clearUnfinished = false,
  }) {
    return RecordingState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      access: access ?? this.access,
      activityId: activityId ?? this.activityId,
      savedActivityId: savedActivityId ?? this.savedActivityId,
      distanceM: distanceM ?? this.distanceM,
      elapsedSec: elapsedSec ?? this.elapsedSec,
      movingSec: movingSec ?? this.movingSec,
      pointCount: pointCount ?? this.pointCount,
      routeForDrawing: routeForDrawing ?? this.routeForDrawing,
      lastPoint: lastPoint ?? this.lastPoint,
      currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
      lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
      calories: calories ?? this.calories,
      unfinished: clearUnfinished ? null : (unfinished ?? this.unfinished),
    );
  }

  @override
  List<Object?> get props => [
    mode,
    status,
    access,
    activityId,
    savedActivityId,
    distanceM,
    elapsedSec,
    movingSec,
    pointCount,
    routeForDrawing.length,
    lastPoint,
    currentSpeedMps,
    lastAccuracyM,
    calories,
    unfinished?.id,
  ];
}
