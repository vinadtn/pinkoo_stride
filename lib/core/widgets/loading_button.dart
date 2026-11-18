import 'package:flutter/material.dart';

/// FilledButton có trạng thái loading: hiện vòng xoay và chặn bấm lặp.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }
}
