import 'package:flutter/material.dart';

import 'app_color_schemes.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Ráp ColorScheme + AppColors + Typography + style từng component thành ThemeData.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColorSchemes.light, AppColors.light);
  static ThemeData get dark => _build(AppColorSchemes.dark, AppColors.dark);

  static ThemeData _build(ColorScheme scheme, AppColors appColors) {
    final radius = BorderRadius.circular(AppDimens.radiusLg);
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusPill));
    const buttonSize = Size(64, AppDimens.buttonHeight);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: appColors.paper,
      extensions: <ThemeExtension<dynamic>>[appColors],

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appColors.paper,
        foregroundColor: appColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        // --surface (trắng) nổi trên --paper (hồng nhạt), viền --line.
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: appColors.line),
        ),
      ),
      // Tabbar dưới: tab đang chọn là viên hồng nhạt chữ hồng đậm (`.tabbar button[aria-current]`).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: appColors.pinkSoft,
        indicatorShape: pill,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected) ? appColors.pinkDeep : appColors.ink3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? appColors.pinkDeep : appColors.ink3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.md,
        ),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      // Nút chính của prototype đều bo tròn hết (`.playbtn`, `.kbtn`).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, shape: pill),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: buttonSize, shape: pill),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: pill,
          side: BorderSide(color: appColors.line2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: pill),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: BorderSide(color: appColors.line2),
        backgroundColor: scheme.surfaceContainerLowest,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: appColors.pinkDeep,
        thumbColor: appColors.pinkDeep,
        inactiveTrackColor: appColors.sunken,
      ),
      dividerTheme: DividerThemeData(color: appColors.line, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.xl)),
        ),
      ),
    );
  }
}
