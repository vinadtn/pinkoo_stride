import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../domain/map_style_choice.dart';

/// Nút đổi kiểu bản đồ, nổi trên góc bản đồ.
///
/// Bấm ra một menu nhỏ thay vì bày sẵn 4 nút: trên màn đang ghi thì bản đồ là
/// thứ cần nhìn, không phải thanh điều khiển.
class MapStyleSwitcher extends StatelessWidget {
  const MapStyleSwitcher({required this.current, required this.onSelected, super.key});

  final MapStyleChoice current;
  final ValueChanged<MapStyleChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final l10n = context.l10n;

    return Material(
      color: context.colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: PopupMenuButton<MapStyleChoice>(
        tooltip: l10n.mapStyleLabel,
        initialValue: current,
        onSelected: onSelected,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        icon: Icon(Icons.layers_rounded, color: c.ink2, size: 22),
        itemBuilder: (context) => [
          for (final style in MapStyleChoice.values)
            PopupMenuItem(
              value: style,
              child: Row(
                children: [
                  Icon(_iconOf(style), size: 19, color: style == current ? c.pinkDeep : c.ink3),
                  const SizedBox(width: AppDimens.md),
                  Text(
                    _labelOf(style, context),
                    style: style == current
                        ? context.textTheme.labelLarge?.copyWith(color: c.pinkDeep)
                        : context.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _labelOf(MapStyleChoice style, BuildContext context) => switch (style) {
    MapStyleChoice.streets => context.l10n.mapStyleStreets,
    MapStyleChoice.satellite => context.l10n.mapStyleSatellite,
    MapStyleChoice.outdoors => context.l10n.mapStyleOutdoors,
    MapStyleChoice.dark => context.l10n.mapStyleDark,
  };

  IconData _iconOf(MapStyleChoice style) => switch (style) {
    MapStyleChoice.streets => Icons.map_rounded,
    MapStyleChoice.satellite => Icons.satellite_alt_rounded,
    MapStyleChoice.outdoors => Icons.terrain_rounded,
    MapStyleChoice.dark => Icons.dark_mode_rounded,
  };
}
