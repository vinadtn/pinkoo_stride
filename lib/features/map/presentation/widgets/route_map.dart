import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../../../app/config/app_environment.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../activity/domain/entities/track_point.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../domain/map_style_choice.dart';
import 'map_placeholder.dart';

/// Bản đồ vẽ đường đã đi.
///
/// Dùng cho cả hai chỗ:
/// - **đang ghi** ([followPuck] = true): camera đi theo người dùng, có mũi chỉ hướng;
/// - **xem lại** ([followPuck] = false): camera khớp vừa toàn bộ đường.
///
/// Đường vẽ theo đúng kiểu prototype: một viền trắng bọc ngoài, lõi màu theo
/// chế độ. Mapbox làm được bằng `lineBorderColor`/`lineBorderWidth` nên chỉ cần
/// một annotation, không phải xếp hai lớp như bản SVG.
class RouteMap extends StatefulWidget {
  const RouteMap({
    required this.mode,
    required this.style,
    required this.route,
    this.followPuck = false,
    this.progressRoute,
    this.markerPoint,
    this.showStartFinish = false,
    super.key,
  });

  final ActivityMode mode;
  final MapStyleChoice style;

  /// Đường đã đi (nên truyền bản đã rút gọn, không phải toàn bộ điểm gốc).
  final List<TrackPoint> route;

  /// Camera dính theo vị trí hiện tại — dùng khi đang ghi.
  final bool followPuck;

  /// Phần đường đã tua qua khi xem lại, vẽ màu nổi đè lên đường chính.
  final List<TrackPoint>? progressRoute;

  /// Vị trí marker mascot khi tua lại.
  final TrackPoint? markerPoint;

  /// Hiện pin S (bắt đầu) và F (kết thúc).
  final bool showStartFinish;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  mb.MapboxMap? _map;
  mb.PolylineAnnotationManager? _lines;
  mb.PointAnnotationManager? _pins;

  /// Vẽ lại đường tốn một vòng gọi qua platform channel, nên chỉ vẽ khi số điểm
  /// thực sự đổi — không vẽ lại mỗi lần đồng hồ nhảy một giây.
  int _drawnRouteLength = -1;
  int _drawnProgressLength = -1;

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) {
      // Đổi style là Mapbox dựng lại toàn bộ layer → annotation cũ mất theo.
      _lines = null;
      _pins = null;
      _drawnRouteLength = -1;
      _drawnProgressLength = -1;
    }
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppEnvironment.hasMapbox) return const MapPlaceholder();

    return mb.MapWidget(
      key: ValueKey(widget.style),
      styleUri: widget.style.uri,
      viewport: _initialViewport(),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: (_) => _sync(),
    );
  }

  mb.ViewportState _initialViewport() {
    if (widget.followPuck) {
      return const mb.FollowPuckViewportState(
        zoom: 16.5,
        pitch: 0,
        bearing: mb.FollowPuckViewportStateBearingHeading(),
      );
    }
    final line = _lineString(widget.route);
    if (line == null) {
      // Chưa có đường (hoạt động rỗng) — để Mapbox dùng camera mặc định của style.
      return const mb.StyleDefaultViewportState();
    }
    return mb.OverviewViewportState(
      geometry: line,
      geometryPadding: const EdgeInsets.all(48),
      maxZoom: 17,
      animationDuration: Duration.zero,
    );
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _map = map;
    // Logo + bản quyền là điều kiện dùng Mapbox, không được tắt. Chỉ dồn xuống
    // góc cho gọn.
    await map.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
    await map.compass.updateSettings(mb.CompassSettings(enabled: widget.followPuck));

    if (widget.followPuck) {
      await map.location.updateSettings(
        mb.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          puckBearing: mb.PuckBearing.HEADING,
          showAccuracyRing: true,
        ),
      );
    }

    _lines = await map.annotations.createPolylineAnnotationManager();
    _pins = await map.annotations.createPointAnnotationManager();
    await _sync();
  }

  Future<void> _sync() async {
    final lines = _lines;
    if (lines == null) return;

    final route = widget.route;
    final progress = widget.progressRoute ?? const [];
    if (route.length == _drawnRouteLength && progress.length == _drawnProgressLength) {
      return;
    }
    _drawnRouteLength = route.length;
    _drawnProgressLength = progress.length;

    await lines.deleteAll();

    final main = _lineString(route);
    if (main != null) {
      await lines.create(
        mb.PolylineAnnotationOptions(
          geometry: main,
          lineColor: widget.mode.routeColor(dark: widget.style.isDark).toARGB32(),
          lineWidth: 5,
          lineBorderColor: AppPalette.white.toARGB32(),
          lineBorderWidth: 2,
          lineJoin: mb.LineJoin.ROUND,
        ),
      );
    }

    final done = _lineString(progress);
    if (done != null) {
      await lines.create(
        mb.PolylineAnnotationOptions(
          geometry: done,
          lineColor: AppPalette.routeDone.toARGB32(),
          lineWidth: 5,
          lineJoin: mb.LineJoin.ROUND,
        ),
      );
    }

    await _syncPins();
  }

  Future<void> _syncPins() async {
    final pins = _pins;
    final route = widget.route;
    if (pins == null) return;

    await pins.deleteAll();
    if (route.length < 2) return;

    if (widget.showStartFinish) {
      await pins.createMulti([
        mb.PointAnnotationOptions(
          geometry: _point(route.first),
          textField: 'S',
          textSize: 13,
          textColor: AppPalette.white.toARGB32(),
          textHaloColor: AppPalette.success.toARGB32(),
          textHaloWidth: 3,
        ),
        mb.PointAnnotationOptions(
          geometry: _point(route.last),
          textField: 'F',
          textSize: 13,
          textColor: AppPalette.white.toARGB32(),
          textHaloColor: AppPalette.pinkDeep.toARGB32(),
          textHaloWidth: 3,
        ),
      ]);
    }

    final marker = widget.markerPoint;
    if (marker != null) {
      await pins.create(
        mb.PointAnnotationOptions(
          geometry: _point(marker),
          textField: '🐾',
          textSize: 24,
        ),
      );
    }
  }

  /// Khớp camera vừa toàn bộ đường — gọi từ ngoài qua [RouteMapController] nếu
  /// cần, hoặc tự chạy khi mở màn chi tiết.
  Future<void> fitRoute() async {
    final map = _map;
    final line = _lineString(widget.route);
    if (map == null || line == null) return;
    final camera = await map.cameraForCoordinates(
      line.coordinates.map((c) => mb.Point(coordinates: c)).toList(),
      mb.MbxEdgeInsets(top: 48, left: 48, bottom: 48, right: 48),
      null,
      null,
    );
    await map.flyTo(camera, mb.MapAnimationOptions(duration: 600));
  }

  mb.LineString? _lineString(List<TrackPoint> points) {
    if (points.length < 2) return null;
    return mb.LineString(
      coordinates: [for (final p in points) mb.Position(p.lon, p.lat)],
    );
  }

  mb.Point _point(TrackPoint p) => mb.Point(coordinates: mb.Position(p.lon, p.lat));
}
