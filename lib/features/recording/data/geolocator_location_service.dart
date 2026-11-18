import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/theme/app_palette.dart';
import '../../activity_mode/domain/activity_mode.dart';
import '../domain/raw_fix.dart';
import 'location_service.dart';

/// Nguồn vị trí thật, qua plugin `geolocator`.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService(this._logger);

  final AppLogger _logger;

  @override
  Future<LocationAccess> ensurePermission({bool requestAlways = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Xin "mọi lúc" là một hộp thoại RIÊNG và chỉ hiện được sau khi đã có
    // quyền khi-đang-dùng; gọi sớm hơn thì Android bỏ qua không hỏi gì.
    if (requestAlways && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always => LocationAccess.always,
      LocationPermission.whileInUse => LocationAccess.whileInUse,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      LocationPermission.denied || LocationPermission.unableToDetermine =>
        LocationAccess.denied,
    };
  }

  @override
  Stream<RawFix> watch(ActivityMode mode) =>
      Geolocator.getPositionStream(locationSettings: _settings(mode)).map(_toFix);

  @override
  Future<RawFix?> currentFix() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _toFix(p);
    } on Exception catch (e) {
      // Trong nhà, lần đầu mở app: rất hay timeout. Không phải lỗi cần ồn ào.
      _logger.w('Chưa lấy được vị trí hiện tại: $e');
      return null;
    }
  }

  LocationSettings _settings(ActivityMode mode) {
    if (kIsWeb) return _base(mode);

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: mode.gpsDistanceFilterM,
        intervalDuration: const Duration(seconds: 1),
        // Thiếu khối này là tắt màn hình xong mất luôn nửa buổi tập: Android
        // chỉ cấp vị trí liên tục cho app có foreground service đang chạy.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Pinkoo Stride đang ghi',
          notificationText: 'Đang theo dấu đường bạn đi — chạm để mở lại.',
          notificationChannelName: 'Ghi hoạt động',
          enableWakeLock: true,
          setOngoing: true,
          color: AppPalette.pinkDeep,
        ),
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: mode.gpsDistanceFilterM,
        activityType: switch (mode) {
          ActivityMode.ride => ActivityType.fitness,
          ActivityMode.run || ActivityMode.walk || ActivityMode.swim => ActivityType.fitness,
        },
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return _base(mode);
  }

  LocationSettings _base(ActivityMode mode) => LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: mode.gpsDistanceFilterM,
  );

  RawFix _toFix(Position p) => RawFix(
    lat: p.latitude,
    lon: p.longitude,
    timestamp: p.timestamp,
    accuracyM: p.accuracy,
    elevationM: p.altitude,
    speedMps: p.speed,
  );
}
