import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/snackbar_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/geo/simplify_route.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/track_point.dart';
import '../../../map/data/map_style_store.dart';
import '../../../map/data/static_map_url.dart';
import '../../data/gpx_export.dart';
import '../../data/story_share.dart';
import '../../data/widget_to_png.dart';
import '../../domain/share_card_style.dart';
import '../widgets/share_card.dart';

/// Mở sheet chia sẻ cho một hoạt động.
Future<void> showShareSheet(BuildContext context, Activity activity) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ShareSheet(activity: activity),
);

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.activity});

  final Activity activity;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  final _storage = sl<LocalStorage>();

  late ShareCardStyle _style = ShareCardStyle.fromId(
    _storage.getString(StorageKeys.shareCardStyle),
  );

  /// Rút gọn mạnh: thẻ nhỏ nên mắt không thấy khác, mà vẽ nhanh hơn nhiều.
  late final List<TrackPoint> _sketchRoute = simplifyRoute(
    widget.activity.points,
    toleranceM: 3,
  );

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        AppDimens.lg,
        AppDimens.lg,
        AppDimens.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(l10n.shareTitle, style: context.textTheme.titleLarge),
          ),
          const SizedBox(height: AppDimens.lg),

          // Thẻ hiện ở kích thước nhỏ cho vừa màn hình, nhưng chụp ra vẫn
          // 1080×1920 nhờ `Transform.scale` + pixelRatio khi capture.
          Center(
            child: _CardPreview(
              cardKey: _cardKey,
              activity: widget.activity,
              style: _style,
              route: _sketchRoute,
              mapImage: _mapImage(),
            ),
          ),
          const SizedBox(height: AppDimens.lg),

          SegmentedButton<ShareCardStyle>(
            segments: [
              ButtonSegment(
                value: ShareCardStyle.pink,
                label: Text(l10n.shareCardStylePink),
              ),
              ButtonSegment(
                value: ShareCardStyle.ocean,
                label: Text(l10n.shareCardStyleOcean),
              ),
              ButtonSegment(
                value: ShareCardStyle.map,
                label: Text(l10n.shareCardStyleMap),
              ),
            ],
            selected: {_style},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _style = s.first);
              _storage.setString(StorageKeys.shareCardStyle, s.first.id);
            },
          ),
          const SizedBox(height: AppDimens.lg),

          FilledButton.icon(
            onPressed: _busy ? null : _shareStory,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(l10n.shareStory),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: AppDimens.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _shareImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(l10n.shareImage),
          ),
          const SizedBox(height: AppDimens.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _shareGpx,
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.shareGpx),
          ),
          const SizedBox(height: AppDimens.sm),
          TextButton.icon(
            onPressed: _busy ? null : _copyCaption,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l10n.shareCopyCaption),
          ),

          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.md),
              child: LinearProgressIndicator(backgroundColor: c.sunken),
            ),
        ],
      ),
    );
  }

  ImageProvider? _mapImage() {
    if (_style != ShareCardStyle.map) return null;
    final url = StaticMapUrl.forRoute(
      route: _sketchRoute,
      style: sl<MapStyleStore>().value,
      routeColorHex: 'CE3F6C',
    );
    return url == null ? null : NetworkImage(url);
  }

  /// Chú thích gợi ý, dán kèm khi đăng.
  String get _caption {
    final a = widget.activity;
    final pace = a.mode.showsSpeed
        ? '${StatFormat.speedKmh(a.avgSpeedKmh)} km/h'
        : StatFormat.pace(a.mode.splitsIn100m ? a.secPer100m : a.secPerKm);
    return '🐾 Pinkoo Stride — ${a.title}\n'
        '${StatFormat.distance(a.distanceM)} · ${StatFormat.duration(a.elapsedSec)} · $pace\n'
        '${a.placeLabel ?? ''}';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Exception catch (e) {
      if (mounted) context.showSnackBar('${context.l10n.errorGeneric} ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareStory() => _run(() async {
    final png = await captureWidgetPng(_cardKey);
    final result = await sl<StoryShare>().shareImage(png, caption: _caption);
    if (!mounted) return;
    final message = switch (result) {
      StoryShareResult.openedInstagram => null,
      StoryShareResult.fellBackNoAppId => context.l10n.shareStoryUnavailable,
      StoryShareResult.fellBackNotInstalled => context.l10n.shareInstagramMissing,
      StoryShareResult.fellBackUnsupportedPlatform => context.l10n.shareInstagramMissing,
    };
    if (message != null) context.showSnackBar(message);
  });

  Future<void> _shareImage() => _run(() async {
    final png = await captureWidgetPng(_cardKey);
    await sl<StoryShare>().shareImageSheet(png, caption: _caption);
  });

  Future<void> _shareGpx() => _run(() async {
    await sl<GpxExport>().share(widget.activity);
  });

  Future<void> _copyCaption() => _run(() async {
    await Clipboard.setData(ClipboardData(text: _caption));
    if (mounted) context.showSnackBar(context.l10n.copied);
  });
}

/// Thẻ thật nằm trong `RepaintBoundary` ở kích thước thiết kế, rồi thu nhỏ bằng
/// `Transform.scale` để xem trước — chụp ra vẫn đủ 1080×1920.
class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.cardKey,
    required this.activity,
    required this.style,
    required this.route,
    required this.mapImage,
  });

  final GlobalKey cardKey;
  final Activity activity;
  final ShareCardStyle style;
  final List<TrackPoint> route;
  final ImageProvider? mapImage;

  @override
  Widget build(BuildContext context) {
    // Cao tối đa 46% chiều cao màn hình để còn chỗ cho các nút bên dưới.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.46;
    final scale = (maxHeight / ShareCard.designHeight).clamp(0.1, 1.0);

    return SizedBox(
      width: ShareCard.designWidth * scale,
      height: ShareCard.designHeight * scale,
      child: FittedBox(
        child: RepaintBoundary(
          key: cardKey,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            child: ShareCard(
              activity: activity,
              style: style,
              route: route,
              mapImage: mapImage,
            ),
          ),
        ),
      ),
    );
  }
}
