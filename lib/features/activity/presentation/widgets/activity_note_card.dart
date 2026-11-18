import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';

/// Ghi chú của người dùng cho một buổi tập.
///
/// Chưa có ghi chú thì chỉ là một nút viền mảnh, không chiếm chỗ của số liệu —
/// phần lớn buổi tập sẽ không có ghi chú, nên trạng thái rỗng phải lặng.
class ActivityNoteCard extends StatelessWidget {
  const ActivityNoteCard({required this.note, required this.onEdit, super.key});

  final String? note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;
    final text = note;

    if (text == null || text.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_note_rounded),
        label: Text(l10n.activityNoteAdd),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.activityNote.toUpperCase(),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: c.ink3,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_outlined, size: 16, color: c.ink3),
                ],
              ),
              const SizedBox(height: AppDimens.xs),
              Text(text, style: context.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
