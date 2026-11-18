import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../domain/auto_pause_stats.dart';

/// Công tắc xem buổi tập theo auto-pause.
///
/// Tắt (mặc định) là số liệu đúng như đã lưu. Bật lên thì màn này tính lại tại
/// chỗ từ các điểm GPS — **không ghi đè gì xuống DB**, nên bật tắt bao nhiêu lần
/// cũng không làm hỏng bản ghi.
class AutoPauseCard extends StatelessWidget {
  const AutoPauseCard({
    required this.stats,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  /// null khi hoạt động chưa nạp điểm GPS.
  final AutoPauseStats? stats;

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;
    final s = stats;

    if (s == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.lg,
          AppDimens.sm,
          AppDimens.sm,
          AppDimens.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.autoPauseTitle, style: context.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        s.hasPauses ? l10n.autoPauseSubtitle : l10n.autoPauseNone,
                        style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  // Không có khoảng nào để trừ thì bật cũng vô nghĩa — khoá luôn
                  // cho khỏi phải thắc mắc vì sao bật mà số không đổi.
                  onChanged: s.hasPauses ? onChanged : null,
                ),
              ],
            ),
            if (enabled && s.hasPauses) ...[
              const SizedBox(height: AppDimens.sm),
              Text(
                l10n.autoPauseDelta(
                  StatFormat.duration(s.original.elapsedSec.toDouble()),
                  StatFormat.duration(s.elapsedSec),
                  StatFormat.duration(s.pausedSec),
                ),
                style: context.textTheme.titleMedium?.copyWith(color: c.pinkDeep),
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                l10n.autoPauseNote,
                style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
