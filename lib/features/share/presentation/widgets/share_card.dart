import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/track_point.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../domain/share_card_style.dart';
import 'route_sketch.dart';

/// Thẻ chia sẻ 9:16 — đúng khổ story, render ra PNG 1080×1920.
///
/// Kích thước vẽ cố định [designWidth]×[designHeight] rồi scale lúc chụp, nên
/// bố cục không phụ thuộc màn hình máy nào: ảnh xuất ra ở máy nào cũng giống nhau.
class ShareCard extends StatelessWidget {
  const ShareCard({
    required this.activity,
    required this.style,
    required this.route,
    this.mapImage,
    super.key,
  });

  /// Kích thước thiết kế (pt). Chụp với pixelRatio = 1080/540 = 2 → 1080×1920.
  static const double designWidth = 540;
  static const double designHeight = 960;

  final Activity activity;
  final ShareCardStyle style;

  /// Đường đi (nên là bản đã rút gọn) để vẽ nét SVG-like trên thẻ.
  final List<TrackPoint> route;

  /// Ảnh bản đồ tĩnh — chỉ dùng cho [ShareCardStyle.map].
  final ImageProvider? mapImage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: designWidth,
      height: designHeight,
      child: DefaultTextStyle(
        style: AppTypography.textTheme.bodyMedium!.copyWith(color: AppPalette.white),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _background(),
            // Lớp tối ở dưới để chữ trắng đọc được trên mọi ảnh bản đồ.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x00000000), Color(0xCC000000)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            if (style != ShareCardStyle.map && route.length >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 150, 60, 300),
                child: RouteSketch(
                  route: route,
                  color: AppPalette.white,
                  strokeWidth: 6,
                ),
              ),
            _header(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _background() => switch (style) {
    ShareCardStyle.pink => const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.pink, AppPalette.pinkDeep],
        ),
      ),
    ),
    ShareCardStyle.ocean => const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.sky, Color(0xFF1E5F7A)],
        ),
      ),
    ),
    ShareCardStyle.map =>
      mapImage == null
          // Chưa tải được ảnh bản đồ (mất mạng, chưa có token) → vẫn ra thẻ dùng
          // được chứ không để ô trống.
          ? const ColoredBox(color: AppPalette.pinkDeep)
          : DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(image: mapImage!, fit: BoxFit.cover),
              ),
            ),
  };

  Widget _header() => Positioned(
    top: 48,
    left: 44,
    right: 44,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'PINKOO STRIDE',
            style: AppTypography.stat(fontSize: 22).copyWith(
              color: AppPalette.white,
              letterSpacing: 2,
            ),
          ),
        ),
        Text(
          [
            if (activity.placeLabel != null) activity.placeLabel!,
            DateFormat('d/M/y').format(activity.startedAt),
          ].join('\n'),
          textAlign: TextAlign.right,
          style: AppTypography.textTheme.bodySmall!.copyWith(
            color: AppPalette.white.withValues(alpha: 0.9),
            height: 1.35,
          ),
        ),
      ],
    ),
  );

  Widget _footer() {
    final mode = activity.mode;
    final paceValue = mode.showsSpeed
        ? StatFormat.speedKmh(activity.avgSpeedKmh)
        : StatFormat.pace(mode.splitsIn100m ? activity.secPer100m : activity.secPerKm);

    return Positioned(
      left: 44,
      right: 44,
      bottom: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${activity.title} ${mode.emoji}',
            style: AppTypography.stat(fontSize: 30).copyWith(color: AppPalette.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Stat(
                label: 'Quãng đường',
                value: StatFormat.distanceValue(activity.distanceM),
                unit: StatFormat.distanceUnit(activity.distanceM),
                size: 42,
              ),
              const SizedBox(width: 28),
              _Stat(label: 'Thời gian', value: StatFormat.duration(activity.elapsedSec)),
              const SizedBox(width: 28),
              _Stat(
                label: mode.showsSpeed ? 'Tốc độ' : 'Pace',
                value: paceValue,
                unit: _plainPaceUnit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Thẻ được render ngoài cây widget của app (không có context mang l10n),
  /// nên đơn vị ở đây viết thẳng.
  String get _plainPaceUnit => switch (activity.mode.paceUnit) {
    PaceUnit.perKm => '/km',
    PaceUnit.per100m => '/100m',
    PaceUnit.speedKmh => 'km/h',
  };
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.unit, this.size = 34});

  final String label;
  final String value;
  final String? unit;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: AppTypography.textTheme.labelSmall!.copyWith(
          color: AppPalette.white.withValues(alpha: 0.85),
          letterSpacing: 1.3,
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: AppTypography.stat(fontSize: size).copyWith(color: AppPalette.white),
          ),
          if (unit != null)
            Text(
              ' $unit',
              style: AppTypography.textTheme.labelLarge!.copyWith(
                color: AppPalette.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    ],
  );
}
