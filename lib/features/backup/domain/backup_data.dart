import '../../activity/domain/entities/activity.dart';

/// Phiên bản định dạng file sao lưu.
///
/// Tăng số này khi cấu trúc JSON đổi theo kiểu bản cũ đọc không ra. App từ chối
/// mở file có version LỚN HƠN số nó biết, và nói rõ là phải cập nhật app —
/// thà báo thẳng còn hơn nạp nửa vời rồi mất dữ liệu.
const int backupFormatVersion = 1;

/// Tên các file bên trong gói `.zip`.
abstract final class BackupEntry {
  static const manifest = 'manifest.json';
  static const activities = 'activities.json';
  static const settings = 'settings.json';
  static const gpxDir = 'gpx';
}

/// Thông tin mô tả gói sao lưu, đọc trước khi đụng tới dữ liệu.
class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.exportedAt,
    required this.activityCount,
    required this.pointCount,
    this.appVersion,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final int activityCount;
  final int pointCount;
  final String? appVersion;

  bool get isReadable => formatVersion <= backupFormatVersion;

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'activityCount': activityCount,
    'pointCount': pointCount,
    if (appVersion != null) 'appVersion': appVersion,
  };

  static BackupManifest fromJson(Map<String, Object?> json) => BackupManifest(
    formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 0,
    exportedAt:
        DateTime.tryParse(json['exportedAt'] as String? ?? '') ?? DateTime.now().toUtc(),
    activityCount: (json['activityCount'] as num?)?.toInt() ?? 0,
    pointCount: (json['pointCount'] as num?)?.toInt() ?? 0,
    appVersion: json['appVersion'] as String?,
  );
}

/// Nội dung đọc ra từ một gói sao lưu.
class BackupBundle {
  const BackupBundle({required this.manifest, required this.activities});

  final BackupManifest manifest;
  final List<Activity> activities;
}

/// Kết quả đối chiếu gói sao lưu với dữ liệu đang có trong máy.
class BackupImportPlan {
  const BackupImportPlan({
    required this.manifest,
    required this.fresh,
    required this.duplicates,
  });

  final BackupManifest manifest;

  /// Chưa có trong máy.
  final List<Activity> fresh;

  /// Đã có — nhận ra qua [backupKeyOf].
  final List<Activity> duplicates;

  int get total => fresh.length + duplicates.length;

  bool get hasAnythingToAdd => fresh.isNotEmpty;
}

/// Khoá nhận diện một buổi tập giữa hai máy: thời điểm bắt đầu + chế độ.
///
/// Không dùng `id` vì id là số tự tăng của riêng từng máy — khôi phục sang máy
/// khác là trùng id với buổi khác ngay. Hai buổi cùng chế độ bắt đầu đúng cùng
/// một giây thì thực tế là một.
String backupKeyOf(Activity activity) =>
    '${activity.mode.id}|${activity.startedAt.toUtc().toIso8601String()}';
