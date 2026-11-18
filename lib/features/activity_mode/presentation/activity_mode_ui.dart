import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/activity_mode.dart';

/// Phần "mặt tiền" của từng chế độ: nhãn, icon, màu.
///
/// Tách khỏi `ActivityMode` để tầng domain không phải biết gì về Flutter —
/// nhờ vậy test logic tính toán chạy được mà không cần dựng widget.
extension ActivityModeUi on ActivityMode {
  String label(AppLocalizations l10n) => switch (this) {
    ActivityMode.run => l10n.modeRun,
    ActivityMode.walk => l10n.modeWalk,
    ActivityMode.swim => l10n.modeSwim,
    ActivityMode.ride => l10n.modeRide,
  };

  IconData get icon => switch (this) {
    ActivityMode.run => Icons.directions_run_rounded,
    ActivityMode.walk => Icons.directions_walk_rounded,
    ActivityMode.swim => Icons.pool_rounded,
    ActivityMode.ride => Icons.directions_bike_rounded,
  };

  String get emoji => switch (this) {
    ActivityMode.run => '🏃',
    ActivityMode.walk => '🚶',
    ActivityMode.swim => '🏊',
    ActivityMode.ride => '🚴',
  };

  /// Màu đường vẽ trên bản đồ. Trên nền tối (vệ tinh, dark) phải dùng tông
  /// sáng hơn, không thì đường chìm vào nền.
  Color routeColor({required bool dark}) => switch (this) {
    ActivityMode.run => dark ? AppPalette.pinkD : AppPalette.pinkDeep,
    ActivityMode.walk => dark ? AppPalette.butter : AppPalette.butterD,
    ActivityMode.swim => dark ? AppPalette.skyD : AppPalette.sky,
    ActivityMode.ride => dark ? AppPalette.pink : AppPalette.pink,
  };

  /// Màu nhấn trong UI (thẻ chọn chế độ, pill).
  Color accent(AppColors c) => switch (this) {
    ActivityMode.run => c.pinkDeep,
    ActivityMode.walk => c.butter,
    ActivityMode.swim => c.sky,
    ActivityMode.ride => c.pink,
  };

  /// Nền nhạt đi kèm [accent].
  Color accentSoft(AppColors c) => switch (this) {
    ActivityMode.run => c.pinkSoft,
    ActivityMode.walk => c.sunken,
    ActivityMode.swim => c.skySoft,
    ActivityMode.ride => c.pinkSoft,
  };

  /// Đơn vị hiển thị cạnh số pace/tốc độ: `/km`, `/100m`, `km/h`.
  String paceUnitLabel(AppLocalizations l10n) => switch (paceUnit) {
    PaceUnit.perKm => l10n.unitPerKm,
    PaceUnit.per100m => l10n.unitPer100m,
    PaceUnit.speedKmh => l10n.unitKmh,
  };

  /// Nhãn cho ô số liệu chính: "Pace" hay "Tốc độ TB".
  String paceStatLabel(AppLocalizations l10n) =>
      showsSpeed ? l10n.statAvgSpeed : l10n.statPace;

  /// Loại ghi vào thẻ `<type>` của file GPX — để Strava, Garmin nhận đúng môn.
  String get gpxType => switch (this) {
    ActivityMode.run => 'running',
    ActivityMode.walk => 'walking',
    ActivityMode.swim => 'swimming',
    ActivityMode.ride => 'cycling',
  };
}
