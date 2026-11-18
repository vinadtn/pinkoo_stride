import 'package:flutter_test/flutter_test.dart';
import 'package:pinkoo_stride/features/recording/data/pending_fix_log.dart';
import 'package:pinkoo_stride/features/recording/domain/raw_fix.dart';

/// Nhật ký điểm mà foreground service ghi ra khi isolate chính đã chết.
///
/// Phần đọc/ghi file cần plugin path_provider nên không test ở đây được; bài
/// test này khoá phần mã hoá — thứ quyết định điểm có về đúng hay không.
void main() {
  final fix = RawFix(
    lat: 16.0731520,
    lon: 108.2469100,
    timestamp: DateTime.utc(2026, 10, 6, 8, 25, 33),
    accuracyM: 4.5,
    elevationM: 2,
    speedMps: 1.25,
  );

  test('mã hoá rồi giải mã ra đúng từng trường', () {
    final back = PendingFixLog.decode(PendingFixLog.encode(fix));

    expect(back.lat, fix.lat);
    expect(back.lon, fix.lon);
    expect(back.timestamp, fix.timestamp);
    expect(back.accuracyM, fix.accuracyM);
    expect(back.elevationM, fix.elevationM);
    expect(back.speedMps, fix.speedMps);
  });

  test('trường rỗng không bị biến thành 0', () {
    final bare = RawFix(lat: 1, lon: 2, timestamp: DateTime.utc(2026));

    final back = PendingFixLog.decode(PendingFixLog.encode(bare));

    expect(back.accuracyM, isNull);
    expect(back.elevationM, isNull);
    expect(back.speedMps, isNull);
  });

  test('mốc thời gian giữ nguyên múi UTC, không lệch giờ', () {
    final local = RawFix(
      lat: 1,
      lon: 2,
      timestamp: DateTime(2026, 10, 6, 15, 25).toUtc(),
    );

    final back = PendingFixLog.decode(PendingFixLog.encode(local));

    expect(back.timestamp.isUtc, isTrue);
    expect(back.timestamp, local.timestamp);
  });

  test('một dòng JSON không chứa xuống dòng — mỗi điểm đúng một dòng', () {
    // Nhật ký là NDJSON: một điểm có xuống dòng là hỏng cả file.
    expect(PendingFixLog.encode(fix).values.join(), isNot(contains('\n')));
  });
}
