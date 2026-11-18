import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_not_found_page.dart';
import '../../features/activity/presentation/pages/activity_detail_page.dart';
import '../../features/activity/presentation/pages/feed_page.dart';
import '../../features/home/presentation/pages/home_shell.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/recording/presentation/cubit/recording_cubit.dart';
import '../../features/recording/presentation/pages/mode_picker_page.dart';
import '../../features/recording/presentation/pages/recording_page.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static GoRouter create() => GoRouter(
    initialLocation: AppRoutes.feed,
    debugLogDiagnostics: kDebugMode,
    routes: [
      // Ba tab giữ nguyên trạng thái của nhau (IndexedStack): đang cuộn giữa
      // bảng tin, nhảy sang Ghi rồi quay lại thì vẫn đúng chỗ cũ.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.feed,
                builder: (_, _) => const FeedPage(),
                routes: [
                  GoRoute(
                    path: 'activity/:id',
                    builder: (_, state) => ActivityDetailPage(
                      activityId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.record, builder: (_, _) => const ModePickerPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(path: 'settings', builder: (_, _) => const SettingsPage()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.recording,
        pageBuilder: (_, state) {
          // Cubit của buổi ghi được tạo ở màn chọn chế độ và đi theo qua `extra`:
          // màn này nằm ngoài shell nên không thấy provider của cây bên kia.
          final cubit = state.extra;
          return NoTransitionPage(
            child: cubit is RecordingCubit
                ? BlocProvider.value(value: cubit, child: const RecordingPage())
                : const AppNotFoundPage(),
          );
        },
      ),
    ],
    errorBuilder: (_, _) => const AppNotFoundPage(),
  );
}
