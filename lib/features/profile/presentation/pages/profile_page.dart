import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../../home/presentation/pages/home_shell.dart';

/// Hồ sơ: tổng kết từ dữ liệu THẬT trong máy, chia theo chế độ.
///
/// Prototype có biểu đồ tuần và huy hiệu bằng số liệu mẫu — ở đây chỉ hiện cái
/// tính được từ dữ liệu có thật, không bày huy hiệu giả.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;

    return StreamBuilder<List<Activity>>(
      stream: sl<ActivityRepository>().watchFinished(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Activity>[];

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.lg),
          children: [
            PageWrap(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.lg),
                      child: Row(
                        children: [
                          Image.asset('assets/images/pinkoo.png', width: 76),
                          const SizedBox(width: AppDimens.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pinkoo', style: context.textTheme.headlineSmall),
                                Text(
                                  '${all.length} hoạt động · '
                                  '${StatFormat.distance(all.fold<double>(0, (a, x) => a + x.distanceM))}',
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: c.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.settingsTitle,
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => context.push('/profile/settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.lg),
                  Text('Theo chế độ', style: context.textTheme.titleLarge),
                  const SizedBox(height: AppDimens.md),
                  for (final mode in ActivityMode.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.md),
                      child: _ModeSummary(
                        mode: mode,
                        activities: all.where((a) => a.mode == mode).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary({required this.mode, required this.activities});

  final ActivityMode mode;
  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final total = activities.fold<double>(0, (a, x) => a + x.distanceM);
    final seconds = activities.fold<int>(0, (a, x) => a + x.elapsedSec);
    final longest = activities.isEmpty
        ? 0.0
        : activities.map((a) => a.distanceM).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: mode.accentSoft(c),
              child: Icon(mode.icon, color: mode.accent(c)),
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label(context.l10n), style: context.textTheme.titleMedium),
                  Text(
                    activities.isEmpty
                        ? 'Chưa có buổi nào'
                        : '${activities.length} buổi · ${StatFormat.duration(seconds)} · '
                              'xa nhất ${StatFormat.distance(longest)}',
                    style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                  ),
                ],
              ),
            ),
            Text(
              StatFormat.distance(total),
              style: AppTypography.stat(fontSize: 19, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
