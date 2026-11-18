import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/geo/gpx.dart';
import '../../../core/logger/app_logger.dart';
import '../../activity/domain/entities/activity.dart';
import '../../activity_mode/presentation/activity_mode_ui.dart';

/// Xuất hoạt động ra file `.gpx` và đẩy sang app khác.
///
/// File GPX là định dạng mở — xuất ra là import được vào Strava, Garmin
/// Connect, Komoot... Đây là cách người dùng mang dữ liệu ra khỏi app, nên nó
/// quan trọng hơn hẳn mấy nút chia sẻ ảnh.
class GpxExport {
  GpxExport(this._logger);

  final AppLogger _logger;

  /// Ghi file vào thư mục cache rồi mở hộp thoại chia sẻ của hệ thống.
  Future<ShareResult> share(Activity activity) async {
    final file = await writeFile(activity);
    _logger.i('Đã ghi ${file.path} (${await file.length()} byte)');
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: activity.title,
        text: activity.title,
      ),
    );
  }

  /// Chỉ ghi file, không chia sẻ — tách ra để test được.
  Future<File> writeFile(Activity activity) async {
    if (activity.points.isEmpty) {
      throw StateError('Hoạt động #${activity.id} không có điểm GPS nào để xuất');
    }

    final xml = Gpx.encode(
      trackName: activity.title,
      startedAt: activity.startedAt,
      trackType: activity.mode.gpxType,
      points: [
        for (final pt in activity.points)
          (lat: pt.lat, lon: pt.lon, tSec: pt.tSec, elevationM: pt.elevationM),
      ],
    );

    // Thư mục con `share/` khớp với khai báo trong res/xml/story_share_paths.xml.
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileNameFor(activity)));
    return file.writeAsString(xml);
  }

  /// `Pinkoo_Run_20261005_0712.gpx` — tên tự mô tả, sắp xếp được theo thời gian.
  static String fileNameFor(Activity activity) {
    final stamp = DateFormat('yyyyMMdd_HHmm').format(activity.startedAt);
    final mode = activity.mode.id;
    return 'Pinkoo_${mode[0].toUpperCase()}${mode.substring(1)}_$stamp.gpx';
  }
}
