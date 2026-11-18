import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';

/// Lối tắt hay dùng trong widget:
///   context.l10n.appTitle
///   context.colorScheme.primary
///   context.appColors.success
///   context.textTheme.titleLarge
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  AppColors get appColors => theme.extension<AppColors>()!;
  bool get isDarkMode => theme.brightness == Brightness.dark;

  AppLocalizations get l10n => AppLocalizations.of(this);
}
