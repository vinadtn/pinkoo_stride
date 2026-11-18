import 'package:flutter/material.dart';

import 'context_extensions.dart';

extension SnackBarX on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? colorScheme.error : null,
        ),
      );
  }
}
