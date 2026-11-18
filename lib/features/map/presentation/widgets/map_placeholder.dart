import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';

/// Hiện thay cho bản đồ khi chưa cấu hình `MAPBOX_TOKEN`.
///
/// Nói rõ phải làm gì thay vì để một ô xám không ai hiểu — mọi phần khác của
/// app (ghi GPS, lưu, xuất .gpx) vẫn chạy bình thường khi chưa có token.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ColoredBox(
      color: c.skySoft,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 40, color: c.ink3),
              const SizedBox(height: AppDimens.md),
              Text(
                'Chưa có token bản đồ',
                style: context.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Token được nén vào APK lúc build, không nhập được ở đây.\n'
                'Dán token vào mobile/env.json rồi build lại app.',
                style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
