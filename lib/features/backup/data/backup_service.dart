import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../../activity/domain/entities/activity.dart';
import '../../activity/domain/repositories/activity_repository.dart';
import '../domain/backup_data.dart';
import 'backup_archive.dart';

/// Kết quả một lần xuất file sao lưu.
class BackupExportResult {
  const BackupExportResult({
    required this.file,
    required this.activityCount,
    required this.byteSize,
  });

  final File file;
  final int activityCount;
  final int byteSize;
}

/// Xuất và nạp lại gói sao lưu.
///
/// Đây là đường DUY NHẤT mang trọn dữ liệu ra khỏi máy. Xuất `.gpx` từng buổi
/// vẫn còn, nhưng GPX chỉ có toạ độ — tên buổi, ghi chú, calo, thời gian di
/// chuyển đều rụng. Gói này giữ đủ.
class BackupService {
  BackupService(this._repository, this._storage, this._logger);

  final ActivityRepository _repository;
  final LocalStorage _storage;
  final AppLogger _logger;

  /// Các key cài đặt được ghi kèm vào gói.
  ///
  /// Hiện CHỈ để mang đi tham khảo — lúc khôi phục app không áp lại cài đặt,
  /// vì đổi ngôn ngữ/giao diện ngay dưới chân người dùng là bất ngờ khó chịu.
  static const _settingKeys = [
    StorageKeys.weightKg,
    StorageKeys.themeMode,
    StorageKeys.languageCode,
    StorageKeys.mapStyle,
    StorageKeys.autoPauseView,
    StorageKeys.shareCardStyle,
  ];

  // ----------------------------------------------------------------- xuất --

  /// Dựng gói `.zip` trong thư mục tạm. Không tự chia sẻ — xem [share].
  Future<BackupExportResult> writeFile({DateTime? now}) async {
    final activities = await _repository.allForBackup();
    final at = now ?? DateTime.now();

    final bytes = BackupArchive.encode(
      activities: activities,
      settings: _settingsSnapshot(),
      exportedAt: at.toUtc(),
    );

    // Cùng thư mục `share/` mà xuất GPX dùng — đã khai trong story_share_paths.xml.
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileNameFor(at)));
    await file.writeAsBytes(bytes, flush: true);

    _logger.i('Đã ghi sao lưu ${file.path} (${bytes.length} byte, '
        '${activities.length} hoạt động)');

    return BackupExportResult(
      file: file,
      activityCount: activities.length,
      byteSize: bytes.length,
    );
  }

  /// Dựng gói rồi mở hộp thoại chia sẻ của hệ thống.
  Future<BackupExportResult> share() async {
    final result = await writeFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.file.path, mimeType: 'application/zip')],
        subject: result.file.uri.pathSegments.last,
      ),
    );
    return result;
  }

  /// `pinkoo-stride-backup-20261006-1545.zip`
  static String fileNameFor(DateTime at) =>
      'pinkoo-stride-backup-${DateFormat('yyyyMMdd-HHmm').format(at)}.zip';

  Map<String, Object?> _settingsSnapshot() {
    final out = <String, Object?>{};
    for (final key in _settingKeys) {
      final value = _readAny(key);
      if (value != null) out[key] = value;
    }
    return out;
  }

  /// Đọc một key mà không cần biết trước nó lưu kiểu gì.
  ///
  /// SharedPreferences ném lỗi ép kiểu khi gọi nhầm getter (xin String ở key
  /// đang giữ double), nên phải thử từng kiểu chứ không chuỗi `??` được.
  Object? _readAny(String key) {
    for (final read in <Object? Function()>[
      () => _storage.getString(key),
      () => _storage.getDouble(key),
      () => _storage.getBool(key),
    ]) {
      try {
        final value = read();
        if (value != null) return value;
      } on Object {
        // Key lưu kiểu khác — thử getter tiếp theo.
      }
    }
    return null;
  }

  // ------------------------------------------------------------- khôi phục --

  /// Đọc gói và đối chiếu với dữ liệu đang có, CHƯA ghi gì xuống DB.
  ///
  /// Tách riêng để màn hình kịp hỏi "bỏ qua trùng hay thêm hết" trước khi động
  /// vào dữ liệu thật.
  Future<BackupImportPlan> plan(Uint8List bytes) async {
    final bundle = BackupArchive.decode(bytes);

    final existing = {
      for (final k in await _repository.finishedKeys())
        '${k.modeId}|${k.startedAt.toUtc().toIso8601String()}',
    };

    final fresh = <Activity>[];
    final duplicates = <Activity>[];
    // Trùng ngay trong chính gói (nhập gói chồng gói) cũng phải bắt, nếu không
    // một lần khôi phục đã tự nhân đôi.
    final seen = <String>{};

    for (final a in bundle.activities) {
      final key = backupKeyOf(a);
      if (existing.contains(key) || !seen.add(key)) {
        duplicates.add(a);
      } else {
        fresh.add(a);
      }
    }

    return BackupImportPlan(
      manifest: bundle.manifest,
      fresh: fresh,
      duplicates: duplicates,
    );
  }

  /// Ghi xuống DB. [includeDuplicates] true là thêm cả những buổi đã có.
  Future<int> apply(BackupImportPlan plan, {bool includeDuplicates = false}) async {
    final toAdd = includeDuplicates
        ? [...plan.fresh, ...plan.duplicates]
        : plan.fresh;
    final added = await _repository.importActivities(toAdd);
    _logger.i('Khôi phục: thêm $added hoạt động '
        '(${plan.duplicates.length} trùng, ${includeDuplicates ? "có" : "không"} nhập lại)');
    return added;
  }
}
