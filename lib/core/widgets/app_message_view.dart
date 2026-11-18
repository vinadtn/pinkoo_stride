import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_dimens.dart';

/// Hiển thị trạng thái lỗi / rỗng, kèm nút thử lại (tuỳ chọn).
class AppMessageView extends StatelessWidget {
  const AppMessageView({
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    super.key,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.appColors.ink3),
            const SizedBox(height: AppDimens.lg),
            Text(message, textAlign: TextAlign.center, style: context.textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimens.xl),
              FilledButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}
