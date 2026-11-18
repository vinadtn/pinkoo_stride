import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/snackbar_extensions.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../activity_mode/domain/activity_mode.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../../map/data/map_style_store.dart';
import '../../../map/domain/map_style_choice.dart';
import '../../../map/presentation/widgets/map_style_switcher.dart';
import '../../../map/presentation/widgets/route_map.dart';
import '../cubit/recording_cubit.dart';
import '../cubit/recording_state.dart';
import '../widgets/gps_quality_chip.dart';
import '../widgets/hold_to_confirm_button.dart';
import '../widgets/live_stat_row.dart';
import '../widgets/swim_lock_overlay.dart';

/// Màn đang ghi: bản đồ chiếm phần lớn, số liệu và nút điều khiển ở dưới.
///
/// Không có tabbar và chặn nút back của hệ thống: đang ghi mà thoát ra là mất
/// mạch, nên muốn ra thì phải Dừng hoặc Bỏ một cách có ý thức.
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  /// Đang khoá màn hình. Chỉ bật được ở chế độ Bơi.
  bool _locked = false;

  @override
  Widget build(BuildContext context) {
    final styleStore = sl<MapStyleStore>();

    return BlocConsumer<RecordingCubit, RecordingState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) async {
        // Buổi ghi kết thúc thì bỏ khoá, để lần ghi sau không mở ra đã bị khoá sẵn.
        if (!state.isLive && _locked) setState(() => _locked = false);

        switch (state.status) {
          case RecordingStatus.saved:
            final id = state.savedActivityId;
            context.read<RecordingCubit>().reset();
            if (id != null) {
              context.pop();
              await context.push(AppRoutes.activityOf(id));
            }
          case RecordingStatus.tooShort:
            context.showSnackBar(
              context.l10n.recordTooShort(ActivityMode.minDistanceToSaveM),
            );
            context.read<RecordingCubit>().reset();
            context.pop();
          case RecordingStatus.discarded:
            context.read<RecordingCubit>().reset();
            context.pop();
          case _:
            break;
        }
      },
      builder: (context, state) {
        final cubit = context.read<RecordingCubit>();
        final l10n = context.l10n;
        final c = context.appColors;
        final busy = state.status == RecordingStatus.saving;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            // Đang khoá thì nút back cũng không thoát được — khoá mà lách được
            // bằng một cú vuốt thì khoá làm gì.
            if (!didPop && !_locked) await _confirmDiscard(context);
          },
          child: Scaffold(
            body: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ValueListenableBuilder<MapStyleChoice>(
                                valueListenable: styleStore,
                                builder: (context, style, _) => RouteMap(
                                  mode: state.mode,
                                  style: style,
                                  route: state.routeForDrawing,
                                  followPuck: true,
                                ),
                              ),
                            ),
                            Positioned(
                              top: AppDimens.md,
                              left: AppDimens.md,
                              child: Row(
                                children: [
                                  _ModePill(mode: state.mode),
                                  const SizedBox(width: AppDimens.sm),
                                  GpsQualityChip(quality: state.gpsQuality),
                                ],
                              ),
                            ),
                            Positioned(
                              top: AppDimens.md,
                              right: AppDimens.md,
                              child: ValueListenableBuilder<MapStyleChoice>(
                                valueListenable: styleStore,
                                builder: (context, style, _) => MapStyleSwitcher(
                                  current: style,
                                  onSelected: styleStore.select,
                                ),
                              ),
                            ),

                            // Khoá màn hình CHỈ có khi bơi: ba chế độ còn lại
                            // cầm máy trên tay, thêm nút vào chỉ tổ rối.
                            if (state.mode == ActivityMode.swim)
                              Positioned(
                                bottom: AppDimens.md,
                                right: AppDimens.md,
                                child: FloatingActionButton.small(
                                  heroTag: 'swim-lock',
                                  tooltip: l10n.recordLock,
                                  backgroundColor: c.skySoft,
                                  foregroundColor: c.sky,
                                  onPressed: () => setState(() => _locked = true),
                                  child: const Icon(Icons.lock_outline_rounded),
                                ),
                              ),

                            if (state.status == RecordingStatus.paused)
                              Positioned(
                                bottom: AppDimens.md,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Chip(
                                    backgroundColor: c.butter,
                                    label: Text(
                                      l10n.recordPause.toUpperCase(),
                                      style: context.textTheme.labelMedium?.copyWith(
                                        color: c.ink,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerLowest,
                          border: Border(top: BorderSide(color: c.line)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimens.lg,
                            AppDimens.lg,
                            AppDimens.lg,
                            AppDimens.sm,
                          ),
                          child: Column(
                            children: [
                              LiveStatRow(state: state),
                              const SizedBox(height: AppDimens.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton.outlined(
                                    tooltip: l10n.recordDiscard,
                                    onPressed: busy
                                        ? null
                                        : () => _confirmDiscard(context),
                                    iconSize: 26,
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                  if (state.status == RecordingStatus.paused)
                                    FilledButton.icon(
                                      onPressed: busy ? null : cubit.resume,
                                      icon: const Icon(Icons.play_arrow_rounded),
                                      label: Text(l10n.recordResume),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(150, 56),
                                      ),
                                    )
                                  else
                                    FilledButton.icon(
                                      onPressed: busy ? null : cubit.pause,
                                      icon: const Icon(Icons.pause_rounded),
                                      label: Text(l10n.recordPause),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(150, 56),
                                        backgroundColor: c.butter,
                                        foregroundColor: c.ink,
                                      ),
                                    ),
                                  HoldToConfirmButton(
                                    label: l10n.recordFinish,
                                    hint: l10n.recordHoldToFinish,
                                    icon: Icons.stop_rounded,
                                    onHoldComplete: busy ? () {} : cubit.finish,
                                  ),
                                ],
                              ),
                              Text(
                                l10n.recordHoldToFinish,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: c.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_locked)
                  SwimLockOverlay(
                    state: state,
                    onUnlock: () => setState(() => _locked = false),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.recordDiscardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.recordDiscard),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await context.read<RecordingCubit>().discard();
    }
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});

  final ActivityMode mode;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Chip(
      backgroundColor: mode.accentSoft(c),
      side: BorderSide(color: mode.accent(c)),
      avatar: Icon(mode.icon, size: 17, color: mode.accent(c)),
      label: Text(
        mode.label(context.l10n),
        style: context.textTheme.labelMedium?.copyWith(color: mode.accent(c)),
      ),
    );
  }
}
