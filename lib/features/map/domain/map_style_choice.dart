import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxStyles;

/// Kiểu bản đồ người dùng chọn được.
///
/// Prototype phải dùng 8 ô ảnh OpenStreetMap tải sẵn vì trang web local không
/// gọi được API có khoá. App thật thì dùng vector tile của Mapbox, nên đổi kiểu
/// chỉ là đổi một chuỗi style URI.
enum MapStyleChoice {
  /// Bản đồ đường phố — mặc định.
  streets(id: 'streets', uri: MapboxStyles.MAPBOX_STREETS, isDark: false),

  /// Ảnh vệ tinh có nhãn đường — cái người dùng hay muốn nhất khi xem lại
  /// đường mình đi ngoài biển / trong rừng.
  satellite(id: 'satellite', uri: MapboxStyles.SATELLITE_STREETS, isDark: true),

  /// Có đường bình độ, đường mòn — hợp chạy trail, đạp xe đường núi.
  outdoors(id: 'outdoors', uri: MapboxStyles.OUTDOORS, isDark: false),

  /// Nền tối, cho buổi tập đêm và cho chế độ tối của app.
  dark(id: 'dark', uri: MapboxStyles.DARK, isDark: true);

  const MapStyleChoice({required this.id, required this.uri, required this.isDark});

  /// Khoá lưu vào SharedPreferences.
  final String id;

  /// Style URI truyền cho `MapWidget`.
  final String uri;

  /// Nền tối → đường vẽ và chữ đè lên phải dùng màu sáng mới đọc được.
  final bool isDark;

  static MapStyleChoice fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => MapStyleChoice.streets);

  /// Tên style tương ứng cho Static Images API (dùng khi render thẻ chia sẻ).
  /// Trả về dạng `owner/style_id` mà API yêu cầu.
  String get staticApiStyle => switch (this) {
    MapStyleChoice.streets => 'mapbox/streets-v12',
    MapStyleChoice.satellite => 'mapbox/satellite-streets-v12',
    MapStyleChoice.outdoors => 'mapbox/outdoors-v12',
    MapStyleChoice.dark => 'mapbox/dark-v11',
  };
}
