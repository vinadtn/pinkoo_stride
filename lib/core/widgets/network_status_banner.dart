import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../extensions/context_extensions.dart';
import '../network/connectivity_cubit.dart';
import '../theme/app_dimens.dart';

enum _BannerKind { offline, reconnected }

/// Thanh báo mạng ở đáy màn hình, áp dụng cho MỌI màn (gắn qua MaterialApp.builder).
///
/// - Mất mạng → hiện "Mất kết nối mạng" cho tới khi có mạng lại.
/// - Có mạng lại → hiện "Đã kết nối lại" trong [reconnectedDuration] rồi ẩn.
/// - Mở app khi đang có mạng → không hiện gì.
class NetworkStatusBanner extends StatefulWidget {
  const NetworkStatusBanner({
    required this.child,
    this.reconnectedDuration = const Duration(seconds: 3),
    super.key,
  });

  final Widget child;
  final Duration reconnectedDuration;

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  _BannerKind? _kind;
  Timer? _hideTimer;

  void _onStatusChanged(NetworkStatus previous, NetworkStatus current) {
    _hideTimer?.cancel();
    if (current == NetworkStatus.offline) {
      setState(() => _kind = _BannerKind.offline);
    } else if (current == NetworkStatus.online && previous == NetworkStatus.offline) {
      setState(() => _kind = _BannerKind.reconnected);
      _hideTimer = Timer(widget.reconnectedDuration, () {
        if (mounted) setState(() => _kind = null);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    NetworkStatus? previous;
    return BlocListener<ConnectivityCubit, NetworkStatus>(
      listenWhen: (prev, curr) {
        previous = prev;
        return prev != curr;
      },
      listener: (_, current) => _onStatusChanged(previous ?? NetworkStatus.unknown, current),
      child: Column(
        children: [
          Expanded(child: widget.child),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: _kind == null ? const SizedBox(width: double.infinity) : _Bar(kind: _kind!),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.kind});

  final _BannerKind kind;

  @override
  Widget build(BuildContext context) {
    final offline = kind == _BannerKind.offline;
    final bg = offline ? context.colorScheme.error : context.appColors.success;
    final fg = offline ? context.colorScheme.onError : context.appColors.onSuccess;

    return Material(
      color: bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.sm, horizontal: AppDimens.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(offline ? Icons.wifi_off : Icons.wifi, size: 18, color: fg),
              const SizedBox(width: AppDimens.sm),
              Text(
                offline ? context.l10n.networkOffline : context.l10n.networkReconnected,
                style: context.textTheme.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
