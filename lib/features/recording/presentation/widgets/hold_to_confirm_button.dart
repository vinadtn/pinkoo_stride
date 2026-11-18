import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_dimens.dart';

/// Nút tròn phải GIỮ vài giây mới ăn.
///
/// Dùng cho hai chỗ đều "lỡ tay là hỏng cả buổi": nút Dừng khi đang ghi, và nút
/// mở khoá màn hình khi bơi. Đang vận động, tay mồ hôi, màn hình trong túi —
/// một cú chạm nhầm không được phép có hậu quả.
///
/// Khó ở chỗ phản hồi: ngón tay che gần hết nút, nên vòng tiến trình mảnh ở
/// giữa coi như không nhìn thấy. Vì vậy báo bằng ba lớp cùng lúc — rung tay khi
/// bắt đầu giữ và khi đủ giờ, quầng sáng loang RA NGOÀI mép ngón tay, và lõi nút
/// co lại để vành tiến trình dày lên thấy rõ.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    required this.label,
    required this.icon,
    required this.onHoldComplete,
    this.hint,
    this.color,
    this.size = AppDimens.recordButtonSize,
    this.holdDuration = const Duration(seconds: 2),
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onHoldComplete;

  /// Câu hướng dẫn cho trình đọc màn hình, ví dụ "Giữ 2 giây để dừng".
  final String? hint;

  /// Màu lõi nút và vành tiến trình. Mặc định là hồng đậm của app.
  final Color? color;

  final double size;
  final Duration holdDuration;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
    // Nhả tay là vòng bật về 0 nhanh, không bắt nhìn nó rút từ từ.
    reverseDuration: const Duration(milliseconds: 220),
  )..addStatusListener(_onStatus);

  /// Đang đặt ngón tay lên nút (khác với `_controller.isAnimating`: lúc nhả tay
  /// vòng chạy ngược về 0 nhưng không còn giữ nữa).
  bool _holding = false;

  /// Chặn bắn hai lần: đổi `value` ngay trong status listener sẽ gọi lại chính
  /// nó, nên đợi hết frame mới reset.
  bool _fired = false;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _fired) return;
    _fired = true;
    unawaited(HapticFeedback.heavyImpact());
    widget.onHoldComplete();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = 0;
      _fired = false;
      setState(() => _holding = false);
    });
  }

  void _startHold() {
    setState(() => _holding = true);
    unawaited(HapticFeedback.selectionClick());
    _controller.forward();
  }

  void _cancelHold() {
    if (!_holding) return;
    setState(() => _holding = false);
    _controller.reverse().ignore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = widget.color ?? c.pinkDeep;
    final size = widget.size;

    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              // Lõi co dần → vành tiến trình dày lên gấp đôi trong lúc giữ.
              final coreSize = size - 18 - 16 * t;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Quầng loang ra ngoài nút, chỗ ngón tay không che.
                  if (t > 0)
                    Positioned.fill(
                      child: OverflowBox(
                        maxWidth: size + 28,
                        maxHeight: size + 28,
                        child: Opacity(
                          opacity: (1 - t) * 0.45,
                          child: Container(
                            width: size + 8 + 20 * t,
                            height: size + 8 + 20 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  CircularProgressIndicator(
                    value: t,
                    strokeWidth: 4 + 2 * t,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.line,
                    color: color,
                  ),
                  Container(
                    width: coreSize,
                    height: coreSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: t > 0
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.45 * t),
                                blurRadius: 12 * t,
                                spreadRadius: 2 * t,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(widget.icon, color: c.onSuccess, size: 30 - 6 * t),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
