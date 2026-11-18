import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../widgets/brand_bar.dart';

/// Khung ngoài của app: 3 tab giữ nguyên trạng thái lẫn nhau + thanh thương hiệu.
///
/// Giống prototype: Bảng tin · Ghi · Hồ sơ. Tab giữa là nơi chọn chế độ, và
/// màn ĐANG GHI nằm ngoài shell này (không có tabbar) để không bấm nhầm sang
/// tab khác giữa buổi tập.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: const BrandBar(),
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.appColors.line)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.view_agenda_outlined),
              selectedIcon: const Icon(Icons.view_agenda_rounded),
              label: l10n.navFeed,
            ),
            NavigationDestination(
              icon: const Icon(Icons.play_circle_outline_rounded),
              selectedIcon: const Icon(Icons.play_circle_rounded),
              label: l10n.navRecord,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lề ngang chuẩn của mọi màn, khớp `.wrap` của prototype (padding 16, tối đa 980).
class PageWrap extends StatelessWidget {
  const PageWrap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
        child: child,
      ),
    ),
  );
}
