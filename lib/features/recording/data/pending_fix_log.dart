import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/raw_fix.dart';

/// Nhật ký điểm GPS mà foreground service ghi ra trong lúc app không còn sống.
///
/// Khi người dùng vuốt app khỏi recents, isolate chính chết theo — không còn ai
/// mở được SQLite. Service vẫn chạy ở isolate riêng, nên nó ghi điểm ra một file
/// text dạng mỗi dòng một JSON. Lần mở app sau, isolate chính đọc file này, nạp
/// vào buổi ghi còn dở rồi xoá đi.
///
/// Cố ý KHÔNG dùng drift ở phía service: mở cùng một file SQLite từ hai isolate
/// là con đường ngắn nhất tới hỏng cơ sở dữ liệu. Thêm dòng vào file text thì
/// không thể hỏng kiểu đó, và cùng lắm mất đúng dòng cuối nếu bị cắt giữa chừng.
class PendingFixLog {
  const PendingFixLog();

  static const _fileName = 'pending_fixes.ndjson';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Ghi thêm một điểm. Gọi từ isolate của service.
  Future<void> append(RawFix fix) async {
    final file = await _file();
    await file.writeAsString(
      '${jsonEncode(encode(fix))}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Đọc hết điểm còn treo, theo đúng thứ tự đã ghi.
  ///
  /// Dòng hỏng (bị cắt giữa chừng lúc hệ thống giết tiến trình) bị bỏ qua chứ
  /// không làm hỏng cả lần đọc.
  Future<List<RawFix>> readAll() async {
    final file = await _file();
    if (!file.existsSync()) return const [];

    final out = <RawFix>[];
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, Object?>) out.add(decode(decoded));
      } on Object {
        // Dòng cuối bị cắt dở — bỏ, phần trước vẫn dùng được.
      }
    }
    return out;
  }

  Future<void> clear() async {
    final file = await _file();
    if (file.existsSync()) await file.delete();
  }

  static Map<String, Object?> encode(RawFix fix) => {
    'lat': fix.lat,
    'lon': fix.lon,
    'ts': fix.timestamp.toUtc().millisecondsSinceEpoch,
    if (fix.accuracyM != null) 'acc': fix.accuracyM,
    if (fix.elevationM != null) 'ele': fix.elevationM,
    if (fix.speedMps != null) 'spd': fix.speedMps,
  };

  static RawFix decode(Map<String, Object?> json) => RawFix(
    lat: (json['lat']! as num).toDouble(),
    lon: (json['lon']! as num).toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (json['ts']! as num).toInt(),
      isUtc: true,
    ),
    accuracyM: (json['acc'] as num?)?.toDouble(),
    elevationM: (json['ele'] as num?)?.toDouble(),
    speedMps: (json['spd'] as num?)?.toDouble(),
  );
}
