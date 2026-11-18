import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Màu TUỲ BIẾN không có trong ColorScheme.
///
/// Ở đây là các token riêng của Pinkoo Stride, lấy nguyên tên từ biến CSS của
/// prototype để đối chiếu nhanh: `paper`, `sunken`, `ink2`, `pinkSoft`,
/// `skySoft`, `butter`, `line`...
///
/// Gắn vào ThemeData qua `extensions`, nên tự đổi theo sáng/tối và có
/// animation khi chuyển theme. Lấy ra bằng `context.appColors.paper`.
///
/// Thêm màu mới: thêm field → thêm vào [light], [dark], [copyWith], [lerp].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.sunken,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.pink,
    required this.pinkDeep,
    required this.pinkSoft,
    required this.sky,
    required this.skySoft,
    required this.butter,
    required this.line,
    required this.line2,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
  });

  /// Nền toàn app (`--paper`) — hồng rất nhạt, không phải trắng.
  final Color paper;

  /// Nền lõm: track của biểu đồ chặng, hàng được hover (`--sunken`).
  final Color sunken;

  /// Chữ chính / phụ / mờ (`--ink`, `--ink-2`, `--ink-3`).
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Hồng Pinkoo (`--pink`, `--pink-deep`, `--pink-soft`).
  final Color pink;
  final Color pinkDeep;
  final Color pinkSoft;

  /// Xanh biển — dùng cho chế độ Bơi (`--sky`, `--sky-soft`).
  final Color sky;
  final Color skySoft;

  /// Vàng bơ — dùng cho chế độ Đi bộ (`--butter`).
  final Color butter;

  /// Viền card, đường kẻ chia (`--line`, `--line-2`).
  final Color line;
  final Color line2;

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  static const light = AppColors(
    paper: AppPalette.paper,
    sunken: AppPalette.sunken,
    ink: AppPalette.ink,
    ink2: AppPalette.ink2,
    ink3: AppPalette.ink3,
    pink: AppPalette.pink,
    pinkDeep: AppPalette.pinkDeep,
    pinkSoft: AppPalette.pinkSoft,
    sky: AppPalette.sky,
    skySoft: AppPalette.skySoft,
    butter: AppPalette.butter,
    line: AppPalette.line,
    line2: AppPalette.line2,
    success: AppPalette.success,
    onSuccess: AppPalette.white,
    warning: AppPalette.warning,
    onWarning: AppPalette.white,
    info: AppPalette.info,
    onInfo: AppPalette.white,
  );

  static const dark = AppColors(
    paper: AppPalette.paperD,
    sunken: AppPalette.sunkenD,
    ink: AppPalette.inkD,
    ink2: AppPalette.ink2D,
    ink3: AppPalette.ink3D,
    pink: AppPalette.pinkD,
    pinkDeep: AppPalette.pinkDeepD,
    pinkSoft: AppPalette.pinkSoftD,
    sky: AppPalette.skyD,
    skySoft: AppPalette.skySoftD,
    butter: AppPalette.butterD,
    line: AppPalette.lineD,
    line2: AppPalette.line2D,
    success: AppPalette.successLight,
    onSuccess: AppPalette.paperD,
    warning: AppPalette.warningLight,
    onWarning: AppPalette.paperD,
    info: AppPalette.infoLight,
    onInfo: AppPalette.paperD,
  );

  @override
  AppColors copyWith({
    Color? paper,
    Color? sunken,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? pink,
    Color? pinkDeep,
    Color? pinkSoft,
    Color? sky,
    Color? skySoft,
    Color? butter,
    Color? line,
    Color? line2,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      sunken: sunken ?? this.sunken,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      pink: pink ?? this.pink,
      pinkDeep: pinkDeep ?? this.pinkDeep,
      pinkSoft: pinkSoft ?? this.pinkSoft,
      sky: sky ?? this.sky,
      skySoft: skySoft ?? this.skySoft,
      butter: butter ?? this.butter,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
    );
  }

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      pinkDeep: Color.lerp(pinkDeep, other.pinkDeep, t)!,
      pinkSoft: Color.lerp(pinkSoft, other.pinkSoft, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skySoft: Color.lerp(skySoft, other.skySoft, t)!,
      butter: Color.lerp(butter, other.butter, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    );
  }
}
