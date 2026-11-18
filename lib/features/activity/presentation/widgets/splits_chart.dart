import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/geo/route_splits.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../activity_mode/domain/activity_mode.dart';

/// Biểu đồ chặng — thanh dài hơn = đi nhanh hơn, y như prototype.
///
/// Vẽ theo **tốc độ** chứ không theo thời gian: nếu lấy thời gian làm độ dài thì
/// chặng chậm lại ra thanh dài, đọc ngược hẳn ý nghĩa.
class SplitsChart extends StatelessWidget {
  const SplitsChart({required this.splits, required this.mode, super.key});

  final List<RouteSplit> splits;
  final ActivityMode mode;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final l10n = context.l10n;
    if (splits.isEmpty) return const SizedBox.shrink();

    final full = splits.where((s) => !s.isPartial).toList();
    final bestIndex = fastestSplitIndex(splits);
    // Chuẩn hoá theo tốc độ của chặng nhanh nhất / chậm nhất trong các chặng đủ
    // độ dài — chặng lẻ không được kéo lệch thang đo.
    final speeds = full.map((s) => s.distanceM / s.durationSec).toList();
    final maxSpeed = speeds.isEmpty ? 1.0 : speeds.reduce((a, b) => a > b ? a : b);
    final minSpeed = speeds.isEmpty ? 0.0 : speeds.reduce((a, b) => a < b ? a : b);

    final unitLabel = mode.splitsIn100m ? '100 m' : '1 km';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.splitsTitle(unitLabel), style: context.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              l10n.splitsHint,
              style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
            ),
            const SizedBox(height: AppDimens.md),

            for (var i = 0; i < splits.length; i++)
              if (!splits[i].isPartial)
                _SplitRow(
                  split: splits[i],
                  isBest: i == bestIndex,
                  fraction: _fractionOf(splits[i], maxSpeed, minSpeed),
                  mode: mode,
                ),

            if (splits.last.isPartial) ...[
              const SizedBox(height: AppDimens.sm),
              Text(
                l10n.splitsRemainder(
                  StatFormat.distanceValue(splits.last.distanceM),
                  StatFormat.duration(splits.last.durationSec),
                ),
                style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
              ),
            ],

            const SizedBox(height: AppDimens.md),
            Wrap(
              spacing: AppDimens.lg,
              runSpacing: AppDimens.xs,
              children: [
                _Legend(color: c.pinkDeep, label: l10n.splitsBest),
                _Legend(color: c.pink, label: l10n.splitsOther),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Độ dài thanh: 0,24–1,0. Giữ sàn 0,24 để chặng chậm nhất vẫn thấy được
  /// thanh (prototype dùng `24 + 76 * …`).
  double _fractionOf(RouteSplit split, double maxSpeed, double minSpeed) {
    final speed = split.distanceM / split.durationSec;
    final span = maxSpeed - minSpeed;
    final t = span <= 0 ? 1.0 : (speed - minSpeed) / span;
    return 0.24 + 0.76 * t.clamp(0.0, 1.0);
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.split,
    required this.isBest,
    required this.fraction,
    required this.mode,
  });

  final RouteSplit split;
  final bool isBest;
  final double fraction;
  final ActivityMode mode;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final barColor = isBest ? c.pinkDeep : c.pink;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${split.index}',
              textAlign: TextAlign.right,
              style: context.textTheme.labelMedium?.copyWith(color: c.ink3),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 17,
                color: c.sunken,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          SizedBox(
            width: 52,
            child: Text(
              StatFormat.duration(split.durationSec),
              textAlign: TextAlign.right,
              style: context.textTheme.labelLarge?.copyWith(
                color: isBest ? c.pinkDeep : c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: AppDimens.xs),
      Text(
        label,
        style: context.textTheme.bodySmall?.copyWith(color: context.appColors.ink3),
      ),
    ],
  );
}
