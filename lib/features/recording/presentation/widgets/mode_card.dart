import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';

/// Một thẻ chọn chế độ: icon lớn, tên, và đơn vị mà chế độ đó đo.
///
/// Có ghi đơn vị ngay trên thẻ (`/km`, `/100m`, `km/h`) vì đó là khác biệt thật
/// giữa bốn chế độ — người bơi cần pace /100 m, người đạp xe cần km/h.
class ModeCard extends StatelessWidget {
  const ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ActivityMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final accent = mode.accent(c);
    final radius = BorderRadius.circular(AppDimens.radiusLg);

    return Semantics(
      button: true,
      selected: selected,
      label: mode.label(context.l10n),
      child: Material(
        color: selected ? mode.accentSoft(c) : context.colorScheme.surfaceContainerLowest,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.lg,
              horizontal: AppDimens.md,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? accent : c.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(mode.icon, size: 34, color: selected ? accent : c.ink2),
                const SizedBox(height: AppDimens.sm),
                Text(
                  mode.label(context.l10n),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: selected ? accent : c.ink,
                  ),
                ),
                Text(
                  mode.paceUnitLabel(context.l10n),
                  style: context.textTheme.labelMedium?.copyWith(color: c.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
