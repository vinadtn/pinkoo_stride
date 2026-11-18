import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_dimens.dart';

/// Thanh tua lại buổi tập: nút Xem lại + slider + số mét.
///
/// Chạy hết đường trong 7 giây, đúng như prototype — đủ nhanh để không sốt ruột,
/// đủ chậm để thấy hình dáng đường đi.
class ReplayBar extends StatefulWidget {
  const ReplayBar({
    required this.progress,
    required this.distanceM,
    required this.onChanged,
    this.replayDuration = const Duration(seconds: 7),
    super.key,
  });

  /// 0..1 theo quãng đường.
  final double progress;
  final double distanceM;
  final ValueChanged<double> onChanged;
  final Duration replayDuration;

  @override
  State<ReplayBar> createState() => _ReplayBarState();
}

class _ReplayBarState extends State<ReplayBar> {
  Timer? _timer;

  bool get _playing => _timer != null;

  /// Nhịp 20 lần/giây: mượt mắt mà không bắt bản đồ vẽ lại quá dày.
  static const _tick = Duration(milliseconds: 50);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_playing) {
      _stop();
      return;
    }
    // Đang ở cuối thì bấm lại là phát từ đầu.
    if (widget.progress >= 0.999) widget.onChanged(0);

    final step = _tick.inMilliseconds / widget.replayDuration.inMilliseconds;
    setState(() {
      _timer = Timer.periodic(_tick, (_) {
        final next = widget.progress + step;
        if (next >= 1) {
          widget.onChanged(1);
          _stop();
        } else {
          widget.onChanged(next);
        }
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    if (mounted) setState(() => _timer = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
            label: Text(_playing ? l10n.replayPause : l10n.replayPlay),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
              textStyle: context.textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Slider(
              value: widget.progress.clamp(0, 1),
              label: StatFormat.distance(widget.distanceM * widget.progress),
              onChanged: (v) {
                // Kéo tay thì dừng phát tự động, không giành nhau con trỏ.
                if (_playing) _stop();
                widget.onChanged(v);
              },
            ),
          ),
          SizedBox(
            width: 68,
            child: Text(
              StatFormat.distance(widget.distanceM * widget.progress),
              textAlign: TextAlign.right,
              style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
