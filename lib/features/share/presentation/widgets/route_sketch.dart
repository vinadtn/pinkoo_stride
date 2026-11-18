import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../activity/domain/entities/track_point.dart';

/// Vẽ hình dáng đường đi bằng nét đơn, không có bản đồ phía sau.
///
/// Dùng cho thẻ chia sẻ kiểu Hồng / Biển: cái người xem nhận ra là *hình dáng*
/// quãng đường, chứ không phải tên phố — nên bỏ bản đồ đi lại sạch hơn.
class RouteSketch extends StatelessWidget {
  const RouteSketch({
    required this.route,
    required this.color,
    this.strokeWidth = 5,
    super.key,
  });

  final List<TrackPoint> route;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SketchPainter(route, color, strokeWidth));
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.route, this.color, this.strokeWidth);

  final List<TrackPoint> route;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2 || size.isEmpty) return;

    var minLat = route.first.lat, maxLat = route.first.lat;
    var minLon = route.first.lon, maxLon = route.first.lon;
    for (final p in route) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }

    // 1 độ kinh tuyến ngắn hơn 1 độ vĩ tuyến theo cos(lat) — bỏ qua là đường
    // bơi dọc bờ biển sẽ phình ngang.
    final lonScale = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = ((maxLon - minLon) * lonScale).abs();
    final spanY = (maxLat - minLat).abs();
    if (spanX == 0 && spanY == 0) return;

    // Co vừa khung nhưng giữ đúng tỉ lệ hai chiều, nên đường không méo.
    final sx = spanX == 0 ? double.infinity : size.width / spanX;
    final sy = spanY == 0 ? double.infinity : size.height / spanY;
    final scale = math.min(sx, sy);
    if (!scale.isFinite) return;

    final drawnW = spanX * scale;
    final drawnH = spanY * scale;
    final offsetX = (size.width - drawnW) / 2;
    final offsetY = (size.height - drawnH) / 2;

    final path = Path();
    for (var i = 0; i < route.length; i++) {
      final p = route[i];
      final x = offsetX + (p.lon - minLon) * lonScale * scale;
      // Vĩ độ tăng về phía bắc, trục y của canvas tăng xuống dưới → đảo lại.
      final y = offsetY + drawnH - (p.lat - minLat) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Bóng mờ phía sau để nét trắng không chìm vào vùng nền sáng của ảnh bản đồ.
    canvas.drawPath(
      path,
      Paint.from(base)
        ..color = const Color(0x40000000)
        ..strokeWidth = strokeWidth + 4,
    );
    canvas.drawPath(
      path,
      Paint.from(base)
        ..color = color
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      old.route.length != route.length ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
