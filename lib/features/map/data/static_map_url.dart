import '../../../app/config/app_environment.dart';
import '../../../core/geo/lat_lng.dart';
import '../../../core/geo/polyline_codec.dart';
import '../../../core/geo/simplify_route.dart';
import '../domain/map_style_choice.dart';

/// Dựng URL ảnh bản đồ tĩnh của Mapbox, có vẽ đường đi.
///
/// Dùng cho thẻ chia sẻ: thẻ phải render ra PNG ngay cả khi widget bản đồ không
/// hiển thị, nên chụp màn hình widget map là không ổn — gọi API lấy ảnh thì chắc
/// chắn hơn và cho ra đúng kích thước cần.
abstract final class StaticMapUrl {
  /// Mapbox giới hạn 1280×1280 cho mỗi ảnh; `@2x` nhân đôi số pixel thật.
  /// 540×960 @2x = **1080×1920**, đúng khổ story 9:16.
  static const int widthPt = 540;
  static const int heightPt = 960;

  /// URL dài quá thì Mapbox trả 414. Rút đường còn tối đa chừng này điểm trước
  /// khi mã hoá — ảnh nhỏ như thế mắt không thấy khác.
  static const int maxPathPoints = 100;

  /// Trả về null khi chưa cấu hình token, hoặc đường quá ngắn để vẽ.
  static String? forRoute({
    required List<LatLng> route,
    required MapStyleChoice style,
    required String routeColorHex,
  }) {
    if (!AppEnvironment.hasMapbox || route.length < 2) return null;

    final encoded = PolylineCodec.encode(_thin(route));
    final path = 'path-5+${_hex(routeColorHex)}-0.95($encoded)';

    return Uri.https('api.mapbox.com', '/styles/v1/${style.staticApiStyle}/static/$path/auto/${widthPt}x$heightPt@2x', {
      'access_token': AppEnvironment.mapboxToken,
      'padding': '60,40,160,40', // chừa chỗ dưới cho khối số liệu của thẻ
      'logo': 'true', // ghi công Mapbox là điều kiện sử dụng, không được tắt
    }).toString();
  }

  /// Nới dần sai số cho tới khi còn dưới [maxPathPoints] điểm.
  static List<LatLng> _thin(List<LatLng> route) {
    var tolerance = 1.0;
    var thinned = route;
    while (thinned.length > maxPathPoints && tolerance < 500) {
      thinned = simplifyRoute(route, toleranceM: tolerance);
      tolerance *= 2;
    }
    return thinned;
  }

  /// API nhận mã màu 3 hoặc 6 ký tự, không có dấu `#`.
  static String _hex(String value) => value.replaceAll('#', '').toLowerCase();
}
