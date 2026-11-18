import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../domain/auto_pause_stats.dart';
import '../../domain/entities/activity.dart';

/// Bốn ô số liệu chính + bốn ô phụ, dựng lại `.bigstats` và `.minis` của prototype.
class BigStatsGrid extends StatelessWidget {
  const BigStatsGrid({
    required this.activity,
    required this.fastestSplitSec,
    this.autoPause,
    super.key,
  });

  final Activity activity;

  /// Khác null khi người dùng bật công tắc auto-pause: thời gian, pace và tốc độ
  /// lấy từ đây thay vì từ [activity]. Quãng đường thì không, vì auto-pause chỉ
  /// trừ thời gian.
  final AutoPauseStats? autoPause;

  /// Thời gian chặng nhanh nhất, null khi chưa đủ một chặng.
  final double? fastestSplitSec;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;
    final mode = activity.mode;

    // Bật auto-pause thì mọi con số có dính thời gian đều lấy theo bản tính lại.
    final view = autoPause;
    final elapsedSec = view?.elapsedSec ?? activity.elapsedSec.toDouble();
    final secPerKm = view?.secPerKm ?? activity.secPerKm;
    final secPer100m = view?.secPer100m ?? activity.secPer100m;
    final avgSpeedKmh = view?.avgSpeedKmh ?? activity.avgSpeedKmh;

    final primary = <({String label, String value, String? unit})>[
      (
        label: l10n.statDistance,
        value: StatFormat.distanceValue(activity.distanceM),
        unit: StatFormat.distanceUnit(activity.distanceM),
      ),
      (label: l10n.statTime, value: StatFormat.duration(elapsedSec), unit: null),
      (
        label: mode.showsSpeed ? l10n.statAvgSpeed : l10n.statAvgPace,
        value: mode.showsSpeed
            ? StatFormat.speedKmh(avgSpeedKmh)
            : StatFormat.pace(mode.splitsIn100m ? secPer100m : secPerKm),
        unit: mode.paceUnitLabel(l10n),
      ),
      (
        label: mode.showsSpeed ? l10n.statPace : l10n.statAvgSpeed,
        value: mode.showsSpeed
            ? StatFormat.pace(secPerKm)
            : StatFormat.speedKmh(avgSpeedKmh),
        unit: mode.showsSpeed ? l10n.unitPerKm : l10n.unitKmh,
      ),
    ];

    final secondary = <({String label, String value})>[
      (label: l10n.statMovingTime, value: StatFormat.duration(activity.movingSec)),
      if (fastestSplitSec != null)
        (
          label:
              '${l10n.statFastestSplit} ${mode.splitsIn100m ? '100 m' : '1 km'}',
          value: StatFormat.duration(fastestSplitSec!),
        ),
      if (activity.calories != null)
        (
          label: l10n.statCalories,
          value: '${StatFormat.calories(activity.calories!)} ${l10n.unitKcal}',
        ),
      (label: l10n.statGpsPoints, value: StatFormat.count(activity.pointCount)),
      if ((activity.elevationGainM ?? 0) > 1)
        (
          label: l10n.statElevation,
          value: '${StatFormat.distanceValue(activity.elevationGainM!)} ${l10n.unitM}',
        ),
    ];

    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, box) {
              // Rộng thì 4 ô một hàng, hẹp thì 2x2 — giống breakpoint 560px của prototype.
              final columns = box.maxWidth >= 520 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.55,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
                children: [
                  for (final s in primary)
                    ColoredBox(
                      color: context.colorScheme.surfaceContainerLowest,
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.md),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.label.toUpperCase(),
                              style: context.textTheme.labelSmall?.copyWith(color: c.ink3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(s.value, style: AppTypography.stat(fontSize: 27)),
                                  if (s.unit != null)
                                    Text(
                                      ' ${s.unit}',
                                      style: context.textTheme.labelLarge?.copyWith(
                                        color: c.ink2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.md),
        Wrap(
          spacing: AppDimens.md,
          runSpacing: AppDimens.md,
          children: [
            for (final s in secondary)
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 150),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.lg,
                      vertical: AppDimens.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          style: context.textTheme.labelMedium?.copyWith(color: c.ink3),
                        ),
                        Text(
                          s.value,
                          style: AppTypography.stat(fontSize: 19, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
