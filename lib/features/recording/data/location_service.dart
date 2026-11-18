import '../../activity_mode/domain/activity_mode.dart';
import '../domain/raw_fix.dart';

/// Kết quả xin quyền vị trí.
enum LocationAccess {
  /// Có quyền cả khi app ở background ("Cho phép mọi lúc") — ghi được khi tắt màn hình.
  always,

  /// Chỉ khi đang mở app. Vẫn ghi được, nhưng hệ thống có thể cắt giữa buổi.
  whileInUse,

  /// Người dùng từ chối lần này.
  denied,

  /// Bị chặn vĩnh viễn — phải vào cài đặt hệ thống mới bật lại được.
  deniedForever,

  /// Dịch vụ vị trí của máy đang tắt.
  serviceDisabled,
}

extension LocationAccessX on LocationAccess {
  bool get canRecord => this == LocationAccess.always || this == LocationAccess.whileInUse;
}

/// Nguồn cấp vị trí.
///
/// Là interface để đổi được bản cài đặt: [GeolocatorLocationService] cho máy
/// thật, và `GpxReplayLocationService` phát lại một file GPX — nhờ đó kiểm thử
/// được toàn bộ luồng ghi trên máy thật mà không cần ra đường.
abstract interface class LocationService {
  /// Kiểm tra và xin quyền nếu chưa có.
  Future<LocationAccess> ensurePermission({bool requestAlways = false});

  /// Dòng vị trí liên tục. Tham số lọc lấy theo [mode].
  ///
  /// Trên Android, stream này chạy kèm foreground service có thông báo thường
  /// trú — không có nó thì hệ thống cắt cập nhật ngay khi tắt màn hình.
  Stream<RawFix> watch(ActivityMode mode);

  /// Một lần định vị để đặt camera bản đồ trước khi bấm Bắt đầu.
  Future<RawFix?> currentFix();
}
