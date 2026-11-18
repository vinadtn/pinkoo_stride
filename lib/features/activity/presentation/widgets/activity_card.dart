import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../domain/entities/activity.dart';

/// Thẻ hoạt động trong bảng tin — dựng lại `.act` của prototype: cột số liệu
/// bên trái, dải màu theo chế độ bên phải.
class ActivityCard extends StatelessWidget {
  const ActivityCard({required this.activity, required this.onTap, super.key});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final l10n = context.l10n;
    final mode = activity.mode;
    final radius = BorderRadius.circular(AppDimens.radiusLg);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: mode.accentSoft(c),
                          child: Icon(mode.icon, size: 18, color: mode.accent(c)),
                        ),
                        const SizedBox(width: AppDimens.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                style: context.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _whenText(activity.startedAt, activity.placeLabel),
                                style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.md),
                    // Ba cột chia đều bề ngang và căn giữa. Để chúng tự co theo
                    // nội dung thì cột "1:03:46" rộng gấp đôi cột "3:00", hàng
                    // số liệu lệch hẳn về bên trái.
                    Row(
                      children: [
                        Expanded(
                          child: _Mini(
                            label: l10n.statDistance,
                            value: StatFormat.distanceValue(activity.distanceM),
                            unit: StatFormat.distanceUnit(activity.distanceM),
                          ),
                        ),
                        Expanded(
                          child: _Mini(
                            label: l10n.statTime,
                            value: StatFormat.duration(activity.elapsedSec),
                          ),
                        ),
                        Expanded(
                          child: _Mini(
                            label: mode.paceStatLabel(l10n),
                            value: mode.showsSpeed
                                ? StatFormat.speedKmh(activity.avgSpeedKmh)
                                : StatFormat.pace(
                                    mode.splitsIn100m
                                        ? activity.secPer100m
                                        : activity.secPerKm,
                                  ),
                            unit: mode.paceUnitLabel(l10n),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Dải màu thay cho hình đường đi: vẽ map tĩnh cho từng thẻ trong
            // danh sách thì vừa chậm vừa tốn quota Mapbox.
            Container(
              width: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [mode.accentSoft(c), mode.accent(c)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _whenText(DateTime at, String? place) {
    final when = DateFormat('EEEE, d MMM · HH:mm', 'vi').format(at);
    return place == null ? when : '$when · $place';
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(color: c.ink3),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.stat(fontSize: 19, weight: FontWeight.w700)),
              if (unit != null)
                Text(
                  ' $unit',
                  style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
