import 'package:flutter/material.dart';

import 'app_palette.dart';

/// ColorScheme Material 3 cho chế độ sáng / tối.
///
/// `fromSeed` sinh đủ ~30 vai trò màu (surface, container, outline...) từ 1 màu gốc,
/// sau đó ghi đè những màu thương hiệu cần chính xác tuyệt đối.
abstract final class AppColorSchemes {
  static final ColorScheme light = ColorScheme.fromSeed(
    seedColor: AppPalette.pink,
    brightness: Brightness.light,
    primary: AppPalette.pinkDeep,
    onPrimary: AppPalette.white,
    primaryContainer: AppPalette.pinkSoft,
    onPrimaryContainer: AppPalette.pinkDeep,
    secondary: AppPalette.sky,
    secondaryContainer: AppPalette.skySoft,
    error: AppPalette.error,
    // --paper là nền toàn app, --surface là nền card.
    surface: AppPalette.paper,
    onSurface: AppPalette.ink,
    surfaceContainerLowest: AppPalette.surface,
    surfaceContainerHighest: AppPalette.sunken,
    outlineVariant: AppPalette.line,
  );

  static final ColorScheme dark = ColorScheme.fromSeed(
    seedColor: AppPalette.pink,
    brightness: Brightness.dark,
    primary: AppPalette.pinkDeepD,
    onPrimary: AppPalette.paperD,
    primaryContainer: AppPalette.pinkSoftD,
    onPrimaryContainer: AppPalette.pinkDeepD,
    secondary: AppPalette.skyD,
    secondaryContainer: AppPalette.skySoftD,
    error: AppPalette.errorLight,
    surface: AppPalette.paperD,
    onSurface: AppPalette.inkD,
    surfaceContainerLowest: AppPalette.surfaceD,
    surfaceContainerHighest: AppPalette.sunkenD,
    outlineVariant: AppPalette.lineD,
  );
}
