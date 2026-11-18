/// Ba kiểu nền thẻ chia sẻ — giữ nguyên bộ của prototype.
enum ShareCardStyle {
  /// Chuyển sắc hồng Pinkoo, đường đi vẽ nét trắng.
  pink('pink'),

  /// Tông xanh biển — hợp buổi bơi.
  ocean('ocean'),

  /// Ảnh bản đồ thật (Mapbox Static Images API) có đường đi vẽ đè.
  map('map');

  const ShareCardStyle(this.id);

  final String id;

  static ShareCardStyle fromId(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => ShareCardStyle.pink);
}
