import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/format/stat_format.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../activity_mode/presentation/activity_mode_ui.dart';
import '../cubit/recording_state.dart';

/// Ba số liệu lớn khi đang ghi: quãng đường · thời gian · pace (hoặc tốc độ).
///
/// Cỡ chữ to hẳn và dùng chữ số đều bề ngang, vì đây là thứ người dùng nhìn khi
/// đang chạy — vừa thở vừa đọc, không có thời gian căn mắt.
///
/// Ba cột chia đều bề ngang và **dùng CHUNG một cỡ chữ**: cỡ chữ được tính từ
/// giá trị dài nhất trong ba cột rồi áp cho cả ba. Để mỗi cột tự co (mỗi ô một
/// `FittedBox`) thì "1:03:46" bị thu nhỏ còn "3:00" thì không, nhìn ra chỗ to
/// chỗ nhỏ dù cùng một hàng.
class LiveStatRow extends StatelessWidget {
  const LiveStatRow({required this.state, super.key});

  final RecordingState state;

  /// Cỡ chữ mong muốn; màn hẹp thì rút xuống nhưng rút đều cả ba cột.
  static const double _maxFontSize = 34;
  static const double _minFontSize = 19;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mode = state.mode;

    final stats = <({String label, String value, String unit})>[
      (
        label: l10n.statDistance,
        value: StatFormat.distanceValue(state.distanceM),
        unit: StatFormat.distanceUnit(state.distanceM),
      ),
      (label: l10n.statTime, value: StatFormat.clock(state.elapsedSec), unit: ''),
      (
        label: mode.paceStatLabel(l10n),
        value: mode.showsSpeed
            ? StatFormat.speedKmh(state.speedKmh)
            : StatFormat.pace(state.paceSecPerUnit),
        unit: mode.paceUnitLabel(l10n),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final fontSize = _sharedFontSize(
          values: [for (final s in stats) s.value],
          // Chừa mỗi bên một chút cho số không chạm sát cột bên cạnh.
          maxWidth: box.maxWidth / stats.length - 8,
          textScaler: MediaQuery.textScalerOf(context),
        );

        return Row(
          children: [
            for (final s in stats)
              Expanded(
                child: _Stat(
                  label: s.label,
                  value: s.value,
                  unit: s.unit,
                  fontSize: fontSize,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Cỡ chữ lớn nhất mà giá trị dài nhất vẫn nằm gọn trong [maxWidth].
  ///
  /// Đo một lần ở cỡ lớn nhất rồi suy ra theo tỉ lệ — bề ngang chữ tỉ lệ thuận
  /// với cỡ chữ, nên không cần dò từng cỡ.
  static double _sharedFontSize({
    required List<String> values,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    if (maxWidth <= 0) return _minFontSize;

    var widest = 0.0;
    for (final v in values) {
      final painter = TextPainter(
        text: TextSpan(text: v, style: AppTypography.stat(fontSize: _maxFontSize)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }

    if (widest <= maxWidth || widest == 0) return _maxFontSize;
    return (_maxFontSize * maxWidth / widest).clamp(_minFontSize, _maxFontSize);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    required this.fontSize,
  });

  final String label;
  final String value;

  /// Chuỗi rỗng khi số liệu không có đơn vị (thời gian) — vẫn dựng Text để ba
  /// cột cao bằng nhau, không cột nào bị đội lên.
  final String unit;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(color: c.ink3),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: AppTypography.stat(fontSize: fontSize),
        ),
        Text(
          unit,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelLarge?.copyWith(color: c.ink2),
        ),
      ],
    );
  }
}
