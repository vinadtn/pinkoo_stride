import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_cubit.dart';

/// Thanh trên cùng: mascot + "PINKOO STRIDE" + nút đổi sáng/tối.
///
/// Dựng lại `.topbar` của prototype, kể cả chữ `STRIDE` tô hồng đậm.
class BrandBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final mode = context.watch<ThemeCubit>().state;

    return AppBar(
      toolbarHeight: 60,
      titleSpacing: AppDimens.lg,
      title: Row(
        children: [
          Image.asset('assets/images/pinkoo.png', width: 38, height: 38),
          const SizedBox(width: AppDimens.sm),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'PINKOO '),
                      TextSpan(text: 'STRIDE', style: TextStyle(color: c.pinkDeep)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  context.l10n.appTagline.toUpperCase(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: c.ink3,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.appearance,
          icon: Icon(switch (mode) {
            ThemeMode.light => Icons.light_mode_rounded,
            ThemeMode.dark => Icons.dark_mode_rounded,
            ThemeMode.system => Icons.brightness_auto_rounded,
          }),
          color: c.ink2,
          onPressed: () => context.read<ThemeCubit>().toggle(context.theme.brightness),
        ),
        const SizedBox(width: AppDimens.sm),
      ],
    );
  }
}
