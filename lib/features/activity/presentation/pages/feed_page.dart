import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../widgets/activity_card.dart';

/// Bảng tin: hoạt động THẬT của chính mình, đọc từ SQLite.
///
/// Prototype hiển thị thêm ba hoạt động của bạn bè — phần đó là dữ liệu mẫu và
/// chỉ có nghĩa khi có backend, nên ở đây chưa làm. Danh sách này 100% là dữ
/// liệu thật, không trộn mẫu vào cho đẹp.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;

    return StreamBuilder<List<Activity>>(
      // Stream của drift tự phát lại mỗi khi bảng đổi, nên lưu xong một buổi là
      // danh sách tự có thêm thẻ — không cần refresh tay.
      stream: sl<ActivityRepository>().watchFinished(),
      builder: (context, snapshot) {
        final activities = snapshot.data;

        if (activities == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (activities.isEmpty) {
          return PageWrap(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/pinkoo.png', width: 110),
                const SizedBox(height: AppDimens.lg),
                Text(l10n.historyEmpty, style: context.textTheme.titleLarge),
                const SizedBox(height: AppDimens.xs),
                Text(
                  l10n.historyEmptyHint,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.lg),
          itemCount: activities.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.md),
          itemBuilder: (context, index) {
            if (index == 0) {
              return PageWrap(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.historyTitle, style: context.textTheme.titleLarge),
                ),
              );
            }
            final activity = activities[index - 1];
            return PageWrap(
              child: ActivityCard(
                activity: activity,
                onTap: () => context.push(AppRoutes.activityOf(activity.id)),
              ),
            );
          },
        );
      },
    );
  }
}
