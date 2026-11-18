import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/locale_cubit.dart';
import '../../core/logger/app_logger.dart';
import '../../core/network/connectivity_cubit.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/theme_cubit.dart';
import '../../features/activity/data/repositories/activity_repository_local.dart';
import '../../features/activity/domain/repositories/activity_repository.dart';
import '../../features/map/data/map_style_store.dart';
import '../../features/recording/data/foreground_location_service.dart';
import '../../features/recording/data/geolocator_location_service.dart';
import '../../features/recording/data/gpx_replay_location_service.dart';
import '../../features/recording/data/location_service.dart';
import '../../features/backup/data/backup_service.dart';
import '../../features/recording/data/split_announcer_impl.dart';
import '../../features/recording/domain/split_alert.dart';
import '../../features/share/data/gpx_export.dart';
import '../../features/share/data/story_share.dart';
import '../config/app_environment.dart';
import '../router/app_router.dart';

/// Service locator toàn app.
final sl = GetIt.instance;

/// Bật nguồn GPS giả (phát lại file GPX) để kiểm thử luồng ghi trên máy thật:
/// `flutter run --dart-define=REPLAY_GPX=true`.
const _replayGpx = bool.fromEnvironment('REPLAY_GPX');

Future<void> configureDependencies(AppEnvironment env) async {
  final prefs = await SharedPreferences.getInstance();

  // ---- Core ----
  sl
    ..registerSingleton<AppEnvironment>(env)
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<LocalStorage>(() => LocalStorage(sl()))
    ..registerLazySingleton(() => TokenStorage(const FlutterSecureStorage()))
    ..registerLazySingleton<AppLogger>(() => AppLogger(enabled: env.enableLogging))
    // Chưa có backend — Dio đăng ký sẵn để lúc có API chỉ cần dùng, không phải
    // dựng lại tầng network.
    ..registerLazySingleton<Dio>(
      () => DioClient.create(env: env, tokenStorage: sl(), logger: sl()),
    )
    ..registerLazySingleton<NetworkInfo>(NetworkInfoImpl.new)
    ..registerSingleton<AppDatabase>(AppDatabase())
    // Cubit dùng chung toàn app → singleton
    ..registerLazySingleton(() => ThemeCubit(sl()))
    ..registerLazySingleton(() => LocaleCubit(sl()))
    ..registerLazySingleton(() => ConnectivityCubit(sl()));

  // ---- Features ----
  sl
    ..registerLazySingleton<ActivityRepository>(() => ActivityRepositoryLocal(sl()))
    ..registerLazySingleton<LocationService>(() {
      final base = _replayGpx
          ? GpxReplayLocationService(bundle: rootBundle)
          : GeolocatorLocationService(sl());
      // Android: bọc thêm foreground service có isolate riêng, để vuốt app khỏi
      // recents vẫn ghi tiếp. Nền tảng khác thì dùng thẳng nguồn bên dưới.
      if (!ForegroundLocationService.isSupported) return base;
      return ForegroundLocationService(base, sl());
    })
    ..registerLazySingleton(() => MapStyleStore(sl()))
    ..registerLazySingleton(() => GpxExport(sl()))
    ..registerLazySingleton(() => BackupService(sl(), sl(), sl()))
    ..registerLazySingleton<SplitAnnouncer>(
      () => SplitAnnouncerRouter(sl(), VoiceSplitAnnouncer(sl())),
    )
    ..registerLazySingleton(() => StoryShare(logger: sl()));

  // ---- Router ----
  sl.registerLazySingleton<GoRouter>(AppRouter.create);
}
