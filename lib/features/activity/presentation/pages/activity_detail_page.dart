import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/geo/route_splits.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/geo/simplify_route.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../../../map/data/map_style_store.dart';
import '../../../map/domain/map_style_choice.dart';
import '../../../map/presentation/widgets/map_style_switcher.dart';
import '../../../map/presentation/widgets/route_map.dart';
import '../../../share/presentation/pages/share_sheet.dart';
import '../../domain/auto_pause_stats.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/repositories/activity_repository.dart';
import '../widgets/activity_note_card.dart';
import '../widgets/auto_pause_card.dart';
import '../widgets/big_stats_grid.dart';
import '../widgets/replay_bar.dart';
import '../widgets/splits_chart.dart';

/// Màn chi tiết một hoạt động: bản đồ + tua lại + số liệu + chặng + chia sẻ.
class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({required this.activityId, super.key});

  final int activityId;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late Future<Activity?> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ActivityRepository>().byId(widget.activityId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Activity?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final activity = snapshot.data;
        if (activity == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.pageNotFound)),
          );
        }
        return _DetailBody(activity: activity);
      },
    );
  }
}

enum _MenuAction { rename, delete }

class _DetailBody extends StatefulWidget {
  const _DetailBody({required this.activity});

  final Activity activity;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  /// Tiến độ tua, 0..1 theo QUÃNG ĐƯỜNG (không theo thời gian) — giống prototype,
  /// nên lúc đứng nghỉ thanh tua không bị đứng im.
  double _progress = 0;

  /// Tên và ghi chú giữ ở state màn này: sửa xong cập nhật tại chỗ, không nạp
  /// lại cả hoạt động — nạp lại là đọc lại hàng nghìn track point cho một dòng chữ.
  late String _title = widget.activity.title;
  late String? _note = widget.activity.note;

  late final List<TrackPoint> _route = simplifyRoute(
    widget.activity.points,
    toleranceM: 1,
  );

  /// Kết quả auto-pause tính một lần khi mở màn — chạy lại mỗi lần bật tắt công
  /// tắc là quét lại vài nghìn điểm cho một thao tác bật/tắt.
  late final AutoPauseStats? _autoPause = autoPauseStatsOf(widget.activity);

  late final _storage = sl<LocalStorage>();

  late bool _autoPauseOn = _storage.getBool(StorageKeys.autoPauseView) ?? false;

  late final List<RouteSplit> _splits = computeSplits(
    widget.activity.points,
    splitDistanceM: widget.activity.mode.splitDistanceM,
  );

  ActivityRepository get _repository => sl<ActivityRepository>();

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final l10n = context.l10n;
    final c = context.appColors;
    final styleStore = sl<MapStyleStore>();

    final bestIndex = fastestSplitIndex(_splits);
    final doneRoute = _progress <= 0 ? const <TrackPoint>[] : _sliceByProgress(_progress);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navFeed),
        actions: [
          PopupMenuButton<_MenuAction>(
            onSelected: (action) => switch (action) {
              _MenuAction.rename => _rename(),
              _MenuAction.delete => _delete(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MenuAction.rename,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.activityRename),
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded, color: context.colorScheme.error),
                  title: Text(
                    l10n.activityDelete,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.xxl),
        children: [
          PageWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimens.md),
                Text(_title, style: context.textTheme.headlineMedium),
                const SizedBox(height: AppDimens.xs),
                Wrap(
                  spacing: AppDimens.sm,
                  runSpacing: AppDimens.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      backgroundColor: activity.mode.accentSoft(c),
                      side: BorderSide(color: activity.mode.accent(c)),
                      avatar: Icon(
                        activity.mode.icon,
                        size: 16,
                        color: activity.mode.accent(c),
                      ),
                      label: Text(
                        activity.mode.label(l10n),
                        style: context.textTheme.labelMedium?.copyWith(
                          color: activity.mode.accent(c),
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM y · HH:mm', 'vi').format(activity.startedAt),
                      style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                    ),
                    if (activity.placeLabel != null)
                      Text(
                        '· ${activity.placeLabel}',
                        style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimens.lg),

                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 340,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ValueListenableBuilder<MapStyleChoice>(
                                valueListenable: styleStore,
                                builder: (context, style, _) => RouteMap(
                                  mode: activity.mode,
                                  style: style,
                                  route: _route,
                                  progressRoute: doneRoute,
                                  markerPoint: doneRoute.isEmpty ? null : doneRoute.last,
                                  showStartFinish: true,
                                ),
                              ),
                            ),
                            Positioned(
                              top: AppDimens.sm,
                              right: AppDimens.sm,
                              child: ValueListenableBuilder<MapStyleChoice>(
                                valueListenable: styleStore,
                                builder: (context, style, _) => MapStyleSwitcher(
                                  current: style,
                                  onSelected: styleStore.select,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ReplayBar(
                        progress: _progress,
                        distanceM: activity.distanceM,
                        onChanged: (v) => setState(() => _progress = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.lg),
                BigStatsGrid(
                  activity: activity,
                  fastestSplitSec: bestIndex < 0 ? null : _splits[bestIndex].durationSec,
                  autoPause: _autoPauseOn ? _autoPause : null,
                ),

                const SizedBox(height: AppDimens.md),
                AutoPauseCard(
                  stats: _autoPause,
                  enabled: _autoPauseOn,
                  onChanged: (on) {
                    setState(() => _autoPauseOn = on);
                    _storage.setBool(StorageKeys.autoPauseView, value: on);
                  },
                ),

                const SizedBox(height: AppDimens.lg),
                ActivityNoteCard(note: _note, onEdit: _editNote),

                const SizedBox(height: AppDimens.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => showShareSheet(context, activity),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(l10n.shareTitle),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimens.lg),
                SplitsChart(splits: _splits, mode: activity.mode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ hành động --

  Future<void> _rename() async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: _title);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activityRenameTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v ?? '').trim().isEmpty ? l10n.activityRenameEmpty : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result == _title) return;
    await _repository.rename(widget.activity.id, result);
    if (!mounted) return;
    setState(() => _title = result);
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    // Lấy trước khi pop: sau khi pop thì context này không còn messenger nào.
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activityDelete),
        content: Text(l10n.activityDeleteConfirm(_title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(l10n.activityDelete),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;

    await _repository.delete(widget.activity.id);
    if (!mounted) return;
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.activityDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _editNote() async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: _note ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.activityNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.activityNoteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null) return;
    // Xoá trắng ô ghi chú = bỏ ghi chú, lưu null chứ không lưu chuỗi rỗng.
    final note = result.isEmpty ? null : result;
    if (note == _note) return;
    await _repository.updateNote(widget.activity.id, note);
    if (!mounted) return;
    setState(() => _note = note);
  }

  /// Phần đường đã tua qua, cắt theo quãng đường cộng dồn.
  List<TrackPoint> _sliceByProgress(double progress) {
    final target = widget.activity.distanceM * progress;
    final out = <TrackPoint>[];
    for (final p in _route) {
      out.add(p);
      if (p.cumulativeM >= target) break;
    }
    return out.length < 2 ? const [] : out;
  }
}

/// Dòng chữ hiển thị quãng đường tại vị trí tua — tách ra cho dễ đọc.
String replayReadout(double distanceM, double progress) =>
    StatFormat.distance(distanceM * progress);
