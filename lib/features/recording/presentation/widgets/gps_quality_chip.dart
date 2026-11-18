import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../cubit/recording_state.dart';

/// Hiện chất lượng GPS khi đang ghi.
///
/// Cần thiết vì GPS yếu là lý do số một làm quãng đường sai — thấy trước thì
/// người dùng biết đứng chờ sóng, chứ không trách app tính nhầm.
class GpsQualityChip extends StatelessWidget {
  const GpsQualityChip({required this.quality, super.key});

  final GpsQuality quality;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final l10n = context.l10n;

    final (label, color, icon) = switch (quality) {
      GpsQuality.unknown => (l10n.gpsSearching, c.ink3, Icons.gps_not_fixed_rounded),
      GpsQuality.weak => (l10n.gpsWeak, c.warning, Icons.gps_off_rounded),
      GpsQuality.fair => (l10n.gpsReady, c.ink2, Icons.gps_fixed_rounded),
      GpsQuality.good => (l10n.gpsReady, c.success, Icons.gps_fixed_rounded),
    };

    return Chip(
      backgroundColor: context.colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
      side: BorderSide(color: c.line),
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: context.textTheme.labelMedium?.copyWith(color: color)),
    );
  }
}
