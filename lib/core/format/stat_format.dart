import 'package:intl/intl.dart';

/// Định dạng số liệu vận động theo kiểu Việt Nam: dấu phẩy thập phân, dấu chấm
/// phân nhóm nghìn — `2,13 km`, `3.812 điểm`.
///
/// Prototype hiển thị `2,13 km`, `1:03:46`, `3:00 /100m`; các hàm ở đây ra đúng
/// chuỗi đó để app và prototype đọc giống nhau.
abstract final class StatFormat {
  static final _oneDecimal = NumberFormat('#,##0.0', 'vi');
  static final _twoDecimal = NumberFormat('#,##0.00', 'vi');
  static final _integer = NumberFormat('#,##0', 'vi');

  /// Quãng đường: dưới 1 km hiện mét (`850 m`), từ 1 km hiện km 2 số (`2,13 km`).
  ///
  /// Trả về chuỗi số, KHÔNG kèm đơn vị — đơn vị lấy từ [distanceUnit] để UI
  /// trình bày cỡ chữ khác nhau cho số và đơn vị như prototype.
  static String distanceValue(double meters) =>
      meters < 1000 ? _integer.format(meters.round()) : _twoDecimal.format(meters / 1000);

  /// Đơn vị tương ứng với [distanceValue] cùng tham số.
  static String distanceUnit(double meters) => meters < 1000 ? 'm' : 'km';

  /// `2,13 km` — dùng ở chỗ chật, không tách đơn vị.
  static String distance(double meters) => '${distanceValue(meters)} ${distanceUnit(meters)}';

  /// `1:03:46` khi có giờ, `12:05` khi chưa tới một giờ.
  static String duration(num seconds) {
    final total = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    return h > 0 ? '$h:$mm:${_two(s)}' : '$mm:${_two(s)}';
  }

  /// `1:03:46` — luôn đủ giờ:phút:giây, dùng cho đồng hồ đang chạy để layout
  /// không nhảy khi vượt mốc 1 giờ.
  static String clock(num seconds) {
    final total = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
    return '${total ~/ 3600}:${_two((total % 3600) ~/ 60)}:${_two(total % 60)}';
  }

  /// Pace `3:00` từ số giây cho mỗi đơn vị (km hoặc 100 m).
  /// `--:--` khi chưa đi được gì, hoặc pace vô lý (trên 100 phút).
  static String pace(double secondsPerUnit) {
    if (!secondsPerUnit.isFinite || secondsPerUnit <= 0 || secondsPerUnit > 6000) {
      return '--:--';
    }
    final total = secondsPerUnit.round();
    return '${total ~/ 60}:${_two(total % 60)}';
  }

  /// Tốc độ `24,5`.
  static String speedKmh(double kmh) =>
      !kmh.isFinite || kmh <= 0 ? '0,0' : _oneDecimal.format(kmh);

  /// Calo `520`.
  static String calories(double kcal) => _integer.format(kcal.round());

  /// Số nguyên có phân nhóm: `3.812`.
  static String count(int value) => _integer.format(value);

  static String _two(int v) => v.toString().padLeft(2, '0');
}
