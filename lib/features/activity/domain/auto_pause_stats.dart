import '../../../core/geo/auto_pause.dart';
import 'entities/activity.dart';

/// Số liệu của một buổi tập khi tính lại theo auto-pause.
///
/// Đây là một CÁCH ĐỌC dữ liệu, không phải dữ liệu mới: không có gì ghi xuống
/// DB, bản ghi gốc giữ nguyên. Người dùng bật/tắt để so hai cách tính.
class AutoPauseStats {
  const AutoPauseStats({
    required this.pauses,
    required this.pausedSec,
    required this.elapsedSec,
    required this.original,
  });

  /// Các khoảng bị coi là đứng yên.
  final List<PausedInterval> pauses;

  /// Tổng thời gian đứng yên đã trừ đi.
  final double pausedSec;

  /// Thời gian sau khi trừ các khoảng đứng yên.
  final double elapsedSec;

  final Activity original;

  /// Có tìm thấy khoảng đứng yên nào không — không có thì bật công tắc cũng
  /// chẳng đổi gì, UI dựa vào đây để nói thẳng điều đó.
  bool get hasPauses => pauses.isNotEmpty;

  /// **Quãng đường không đổi.** Auto-pause bỏ thời gian đứng yên, không bỏ
  /// đường đã đi — đứng yên thì vốn cũng chẳng đi được mét nào.
  double get distanceM => original.distanceM;

  double get secPerKm => distanceM <= 0 ? 0 : elapsedSec / (distanceM / 1000);

  double get secPer100m => distanceM <= 0 ? 0 : elapsedSec / (distanceM / 100);

  double get avgSpeedKmh =>
      elapsedSec <= 0 ? 0 : (distanceM / 1000) / (elapsedSec / 3600);
}

/// Tính lại một hoạt động theo auto-pause, từ chính các điểm GPS đã lưu.
///
/// Trả về null khi hoạt động chưa nạp điểm (màn danh sách không nạp điểm để đỡ
/// phải đọc hàng nghìn dòng chỉ để vẽ một thẻ).
AutoPauseStats? autoPauseStatsOf(Activity activity) {
  if (activity.points.length < 2) return null;

  final pauses = activity.mode.detectPausesIn(activity.points);
  final paused = pausedSeconds(pauses);
  final elapsed = activity.elapsedSec.toDouble();

  return AutoPauseStats(
    pauses: pauses,
    pausedSec: paused,
    // Không bao giờ để ra số âm, kể cả khi ngưỡng bị chỉnh thành vô lý.
    elapsedSec: (elapsed - paused).clamp(0, elapsed),
    original: activity,
  );
}
