import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubit/recording_state.dart';
import 'hold_to_confirm_button.dart';
import 'live_stat_row.dart';

/// Lớp phủ khoá màn hình khi đang bơi.
///
/// Dưới nước, màn hình cảm ứng nhận chạm ma — nước đọng trên kính cũng đủ để
/// bấm trúng nút Dừng. Lớp này nuốt mọi thao tác, chỉ chừa nút mở khoá phải giữ
/// 2 giây.
///
/// Vẫn hiện số liệu trực tiếp: khoá là để khỏi bấm nhầm, không phải để khỏi xem.
///
/// Chỉ dựng ở chế độ Bơi — ba chế độ còn lại cầm máy trên tay nên không cần,
/// thêm nút khoá vào chỉ tổ rối.
class SwimLockOverlay extends StatelessWidget {
  const SwimLockOverlay({required this.state, required this.onUnlock, super.key});

  final RecordingState state;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;

    return Positioned.fill(
      child: GestureDetector(
        // Nuốt mọi chạm, kéo, vuốt. Không có cái này thì nút bên dưới vẫn ăn.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: context.colorScheme.surface.withValues(alpha: 0.97),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Icon(Icons.lock_rounded, size: 34, color: c.ink3),
                      const SizedBox(height: AppDimens.sm),
                      Text(l10n.recordLocked, style: context.textTheme.titleLarge),
                      const SizedBox(height: AppDimens.xs),
                      Text(
                        l10n.recordLockWhySwim,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
                      ),
                    ],
                  ),

                  LiveStatRow(state: state),

                  Column(
                    children: [
                      HoldToConfirmButton(
                        label: l10n.recordUnlock,
                        hint: l10n.recordUnlockHint,
                        icon: Icons.lock_open_rounded,
                        color: c.sky,
                        onHoldComplete: onUnlock,
                      ),
                      const SizedBox(height: AppDimens.sm),
                      Text(
                        l10n.recordUnlockHint,
                        style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
