import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/snackbar_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../data/backup_codec.dart';
import '../../data/backup_service.dart';
import '../../domain/backup_data.dart';

/// Mục Sao lưu trong màn Cài đặt: xuất một gói `.zip` và nạp lại.
///
/// Đây là đường duy nhất mang trọn dữ liệu ra khỏi máy — gỡ app là mất sạch,
/// nên nút này đáng nằm ngay trong Cài đặt chứ không giấu đâu đó.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  BackupService get _service => sl<BackupService>();

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.archive_outlined),
          title: Text(l10n.backupExport),
          subtitle: Text(l10n.backupExportHint),
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : _export,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.unarchive_outlined),
          title: Text(l10n.backupRestore),
          subtitle: Text(l10n.backupRestoreHint),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : _restore,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimens.xs),
          child: Text(
            l10n.backupSettingsKept,
            style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final result = await _service.share();
      if (!mounted) return;
      if (result.activityCount == 0) {
        context.showSnackBar(l10n.backupEmpty);
      } else {
        context.showSnackBar(
          l10n.backupExportDone(result.activityCount, _readableSize(result.byteSize)),
        );
      }
    } on Object catch (e) {
      if (!mounted) return;
      context.showSnackBar(l10n.backupBadFile('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = context.l10n;

    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final plan = await _service.plan(bytes);
      if (!mounted) return;

      if (plan.total == 0) {
        context.showSnackBar(l10n.backupNothingNew);
        return;
      }

      final choice = await _askHowToImport(plan);
      if (choice == null || !mounted) return;

      final added = await _service.apply(plan, includeDuplicates: choice);
      if (!mounted) return;
      context.showSnackBar(
        added == 0 ? l10n.backupNothingNew : l10n.backupRestored(added),
      );
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      context.showSnackBar(l10n.backupBadFile(e.message), isError: true);
    } on Object catch (e) {
      if (!mounted) return;
      context.showSnackBar(l10n.backupBadFile('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Trả về true = thêm hết, false = bỏ qua trùng, null = huỷ.
  ///
  /// Luôn hỏi TRƯỚC khi ghi: người dùng phải thấy "12 mới, 3 đã có" rồi mới
  /// quyết, chứ không phải nhập xong mới biết vừa nhân đôi lịch sử.
  Future<bool?> _askHowToImport(BackupImportPlan plan) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.backupPlanTitle),
        content: Text(l10n.backupPlanSummary(plan.fresh.length, plan.duplicates.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          if (plan.duplicates.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.backupImportAll),
            ),
          FilledButton(
            onPressed: plan.hasAnythingToAdd
                ? () => Navigator.of(dialogContext).pop(false)
                : null,
            child: Text(l10n.backupSkipDuplicates),
          ),
        ],
      ),
    );
  }

  static String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
