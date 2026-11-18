import '../../../activity_mode/domain/activity_mode.dart';
import '../entities/activity.dart';
import '../entities/track_point.dart';

/// Số liệu tổng của một buổi ghi, dùng cho cả lúc autosave giữa buổi và lúc
/// chốt khi bấm Dừng.
class ActivityTotals {
  const ActivityTotals({
    required this.elapsedSec,
    required this.movingSec,
    required this.distanceM,
    required this.pointCount,
    this.elevationGainM,
    this.calories,
  });

  final int elapsedSec;
  final int movingSec;
  final double distanceM;
  final int pointCount;
  final double? elevationGainM;
  final double? calories;
}

/// Kho hoạt động. Hiện chỉ có bản local (SQLite); khi có backend thì thêm một
/// impl nữa đồng bộ lên server, phần trên không phải sửa.
abstract interface class ActivityRepository {
  /// Mở một bản ghi ở trạng thái "đang ghi" và trả về id.
  ///
  /// Ghi vào DB ngay từ lúc bấm Bắt đầu (không đợi tới lúc Dừng) để app bị kill
  /// giữa buổi vẫn còn dữ liệu phục hồi.
  Future<int> startRecording({
    required ActivityMode mode,
    required String title,
    required DateTime startedAt,
  });

  /// Ghi thêm các điểm mới vào buổi đang ghi (gọi theo lô, không từng điểm).
  Future<void> appendPoints(int activityId, List<TrackPoint> points);

  /// Cập nhật số liệu tổng của buổi đang ghi — gọi định kỳ khi autosave.
  Future<void> saveProgress(int activityId, ActivityTotals totals);

  /// Chốt buổi ghi: lưu số liệu cuối và chuyển sang trạng thái đã xong.
  Future<void> finishRecording(
    int activityId, {
    required DateTime endedAt,
    required ActivityTotals totals,
    String? placeLabel,
  });

  /// Buổi đang ghi còn sót lại (app bị kill giữa buổi), hoặc null.
  /// Kèm luôn track point để dựng lại trạng thái.
  Future<Activity?> findUnfinished();

  /// Danh sách hoạt động đã xong, mới nhất trước, KHÔNG kèm track point.
  Stream<List<Activity>> watchFinished();

  Future<Activity?> byId(int id, {bool withPoints = true});

  Future<void> delete(int id);

  Future<void> rename(int id, String title);

  /// Ghi chú của người dùng cho buổi tập. Truyền null để xoá trắng.
  Future<void> updateNote(int id, String? note);

  /// Toàn bộ hoạt động đã xong, KÈM track point — dùng khi xuất file sao lưu.
  Future<List<Activity>> allForBackup();

  /// Chế độ + thời điểm bắt đầu của mọi hoạt động đã xong.
  ///
  /// Đủ để nhận ra bản ghi trùng khi khôi phục, mà không phải nạp hàng vạn
  /// track point chỉ để so hai cái mốc thời gian.
  Future<List<({String modeId, DateTime startedAt})>> finishedKeys();

  /// Chèn hoạt động đọc từ gói sao lưu, trong MỘT transaction.
  ///
  /// Hỏng giữa chừng thì không để lại bản ghi nửa vời. Trả về số buổi đã thêm.
  Future<int> importActivities(List<Activity> activities);
}
