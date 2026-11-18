import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/geo/gpx.dart';
import '../../activity/domain/entities/activity.dart';
import '../../activity_mode/presentation/activity_mode_ui.dart';
import '../../share/data/gpx_export.dart';
import '../domain/backup_data.dart';
import 'backup_codec.dart';

/// Đóng gói và mở gói `.zip` sao lưu.
///
/// Thuần tính toán trên byte, không chạm file hệ thống và không gọi plugin nào —
/// nhờ vậy test được toàn bộ vòng xuất → nhập bằng `flutter test`.
abstract final class BackupArchive {
  /// Dựng nội dung file `.zip`.
  ///
  /// Kèm luôn một thư mục `gpx/` chứa mỗi buổi một file: giải nén ra là nạp
  /// thẳng vào Strava hay Garmin được, không cần app này. Phần `activities.json`
  /// mới là thứ app đọc khi khôi phục — `gpx/` chỉ để mang dữ liệu đi nơi khác.
  static Uint8List encode({
    required List<Activity> activities,
    required Map<String, Object?> settings,
    DateTime? exportedAt,
    String? appVersion,
  }) {
    final manifest = BackupManifest(
      formatVersion: backupFormatVersion,
      exportedAt: exportedAt ?? DateTime.now().toUtc(),
      activityCount: activities.length,
      pointCount: activities.fold(0, (sum, a) => sum + a.points.length),
      appVersion: appVersion,
    );

    final archive = Archive()
      ..addFile(_json(BackupEntry.manifest, manifest.toJson()))
      ..addFile(
        _json(BackupEntry.activities, [
          for (final a in activities) BackupCodec.activityToJson(a),
        ]),
      )
      ..addFile(_json(BackupEntry.settings, settings));

    for (final a in activities) {
      if (a.points.isEmpty) continue;
      final xml = Gpx.encode(
        trackName: a.title,
        startedAt: a.startedAt,
        trackType: a.mode.gpxType,
        points: [
          for (final p in a.points)
            (lat: p.lat, lon: p.lon, tSec: p.tSec, elevationM: p.elevationM),
        ],
      );
      archive.addFile(_text('${BackupEntry.gpxDir}/${GpxExport.fileNameFor(a)}', xml));
    }

    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  /// Đọc gói sao lưu. Ném [BackupFormatException] khi file hỏng hoặc sai cấu trúc.
  static BackupBundle decode(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const BackupFormatException('Không mở được file — có thể không phải .zip');
    }

    final manifestRaw = _read(archive, BackupEntry.manifest);
    if (manifestRaw == null) {
      throw const BackupFormatException('Thiếu manifest.json — đây không phải gói sao lưu');
    }

    final manifest = BackupManifest.fromJson(
      _decodeMap(manifestRaw, BackupEntry.manifest),
    );
    // Kiểm tra phiên bản TRƯỚC khi đọc dữ liệu: định dạng mới hơn thì cấu trúc
    // bên trong có thể đã khác hẳn, cố đọc là hiểu sai chứ không phải lỗi.
    if (!manifest.isReadable) {
      throw BackupFormatException(
        'File tạo bởi bản app mới hơn (định dạng ${manifest.formatVersion}). '
        'Cập nhật app rồi thử lại.',
      );
    }

    final activitiesRaw = _read(archive, BackupEntry.activities);
    if (activitiesRaw == null) {
      throw const BackupFormatException('Thiếu activities.json');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(activitiesRaw);
    } on FormatException {
      throw const BackupFormatException('activities.json không phải JSON hợp lệ');
    }

    return BackupBundle(
      manifest: manifest,
      activities: BackupCodec.activitiesFromJson(decoded),
    );
  }

  static Map<String, Object?> _decodeMap(String raw, String name) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw BackupFormatException('$name sai cấu trúc');
      }
      return decoded;
    } on FormatException {
      throw BackupFormatException('$name không phải JSON hợp lệ');
    }
  }

  static String? _read(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.name == name && file.isFile) {
        return utf8.decode(file.content as List<int>, allowMalformed: true);
      }
    }
    return null;
  }

  static ArchiveFile _json(String name, Object? value) =>
      _text(name, const JsonEncoder.withIndent('  ').convert(value));

  static ArchiveFile _text(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }
}
