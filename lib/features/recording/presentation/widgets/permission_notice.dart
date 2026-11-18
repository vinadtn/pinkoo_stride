import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/location_service.dart';

/// Giải thích vì sao chưa ghi được và cho đúng một nút để xử lý.
///
/// Mỗi trường hợp một cách xử lý khác nhau: thiếu quyền thì xin lại, bị chặn
/// vĩnh viễn thì chỉ mở được cài đặt hệ thống, GPS tắt thì mở cài đặt vị trí.
class PermissionNotice extends StatelessWidget {
  const PermissionNotice({required this.access, required this.onRetry, super.key});

  final LocationAccess access;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final l10n = context.l10n;

    final (String?, String?, VoidCallback?) spec = switch (access) {
      // GPS tắt thì phải vào màn cài đặt VỊ TRÍ của hệ thống, không phải màn
      // cài đặt của app — hai nơi khác nhau.
      LocationAccess.serviceDisabled => (
        l10n.locationServiceOff,
        l10n.permissionOpenSettings,
        () => unawaited(Geolocator.openLocationSettings()),
      ),
      LocationAccess.deniedForever => (
        l10n.permissionDeniedForever,
        l10n.permissionOpenSettings,
        () => unawaited(Geolocator.openAppSettings()),
      ),
      LocationAccess.denied => (
        l10n.permissionLocationBody,
        l10n.permissionGrant,
        onRetry,
      ),
      LocationAccess.always || LocationAccess.whileInUse => (null, null, null),
    };
    final (message, actionLabel, action) = spec;

    if (message == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_off_rounded, size: 20, color: c.warning),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Text(
                    l10n.permissionLocationTitle,
                    style: context.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sm),
            Text(message, style: context.textTheme.bodyMedium?.copyWith(color: c.ink2)),
            const SizedBox(height: AppDimens.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: action, child: Text(actionLabel!)),
            ),
          ],
        ),
      ),
    );
  }
}
