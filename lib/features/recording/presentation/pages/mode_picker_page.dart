import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../cubit/recording_cubit.dart';
import '../cubit/recording_state.dart';
import '../widgets/mode_card.dart';
import '../widgets/permission_notice.dart';

/// Màn chọn chế độ: 4 thẻ + nút Bắt đầu.
///
/// `RecordingCubit` được tạo ở đây và truyền tiếp sang màn đang ghi qua
/// `BlocProvider.value` — một buổi ghi là một cubit, không phải singleton, nên
/// thoát ra là mọi timer/stream đóng theo.
class ModePickerPage extends StatelessWidget {
  const ModePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          RecordingCubit(
            location: sl(),
            repository: sl(),
            storage: sl(),
            logger: sl(),
            splitAnnouncer: sl(),
          )
            ..checkUnfinished(),
      child: const _ModePickerView(),
    );
  }
}

class _ModePickerView extends StatelessWidget {
  const _ModePickerView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;

    return BlocConsumer<RecordingCubit, RecordingState>(
      listenWhen: (prev, next) =>
          prev.unfinished?.id != next.unfinished?.id ||
          (prev.status != next.status && next.status == RecordingStatus.recording),
      listener: (context, state) {
        if (state.unfinished != null) {
          _askRecover(context);
        } else if (state.status == RecordingStatus.recording) {
          // Phục hồi xong → vào thẳng màn đang ghi.
          _openRecording(context);
        }
      },
      builder: (context, state) {
        final cubit = context.read<RecordingCubit>();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppDimens.xxl),
          child: PageWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.xl),
                Text(l10n.modePickerTitle, style: context.textTheme.headlineMedium),
                const SizedBox(height: AppDimens.xs),
                Text(
                  l10n.modePickerSubtitle,
                  style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                ),
                const SizedBox(height: AppDimens.xl),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppDimens.md,
                  crossAxisSpacing: AppDimens.md,
                  childAspectRatio: 1.25,
                  children: [
                    for (final mode in ActivityMode.values)
                      ModeCard(
                        mode: mode,
                        selected: mode == state.mode,
                        onTap: () => cubit.selectMode(mode),
                      ),
                  ],
                ),

                if (state.status == RecordingStatus.blocked && state.access != null) ...[
                  const SizedBox(height: AppDimens.lg),
                  PermissionNotice(access: state.access!, onRetry: cubit.prepare),
                ],

                const SizedBox(height: AppDimens.xl),
                FilledButton.icon(
                  onPressed: state.status == RecordingStatus.preparing
                      ? null
                      : () async {
                          await cubit.start();
                          if (context.mounted &&
                              context.read<RecordingCubit>().state.status ==
                                  RecordingStatus.recording) {
                            _openRecording(context);
                          }
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    state.status == RecordingStatus.preparing
                        ? l10n.gpsSearching
                        : '${l10n.recordStart} · ${state.mode.label(l10n)}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: context.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppDimens.md),
                Text(
                  _hintFor(state.mode, context),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hintFor(ActivityMode mode, BuildContext context) => switch (mode) {
    ActivityMode.swim =>
      'Bơi biển: để máy trong túi chống nước, tín hiệu sẽ kém hơn trên cạn.',
    ActivityMode.ride => 'Gắn máy ở chỗ thoáng để GPS bắt tốt hơn.',
    ActivityMode.run || ActivityMode.walk =>
      'Đứng ngoài trời vài giây cho GPS bắt sóng trước khi bắt đầu.',
  };

  void _openRecording(BuildContext context) {
    final cubit = context.read<RecordingCubit>();
    // Màn đang ghi nằm ngoài shell nên không nhận được provider của cây này —
    // truyền cubit đi theo bằng `extra`.
    context.push(AppRoutes.recording, extra: cubit);
  }

  Future<void> _askRecover(BuildContext context) async {
    final cubit = context.read<RecordingCubit>();
    final found = cubit.state.unfinished;
    if (found == null) return;
    final l10n = context.l10n;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.recoverTitle),
        content: Text(
          l10n.recoverBody(
            found.mode.label(l10n).toLowerCase(),
            StatFormat.distance(found.distanceM),
            StatFormat.duration(found.elapsedSec),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            child: Text(l10n.recoverDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: Text(l10n.recoverSave),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('continue'),
            child: Text(l10n.recoverContinue),
          ),
        ],
      ),
    );

    switch (choice) {
      case 'continue':
        await cubit.continueUnfinished();
      case 'save':
        await cubit.saveUnfinished();
      case 'discard':
        await cubit.discardUnfinished();
      case _:
        break;
    }
  }
}
