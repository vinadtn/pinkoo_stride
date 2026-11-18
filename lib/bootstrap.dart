import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;

import 'app/app.dart';
import 'app/config/app_environment.dart';
import 'app/di/injection.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/logger/app_logger.dart';

/// Khởi tạo mọi thứ trước khi vẽ UI: DI, logger, bắt lỗi toàn cục, token bản đồ.
Future<void> bootstrap(AppEnvironment env) async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies(env);

  final logger = sl<AppLogger>();
  Bloc.observer = AppBlocObserver(logger);

  // Lỗi trong framework (build/layout/paint)
  FlutterError.onError = (details) {
    logger.e(details.exceptionAsString(), error: details.exception, stackTrace: details.stack);
  };
  // Lỗi async không được bắt
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Uncaught error', error: error, stackTrace: stack);
    return true;
  };

  // Token bản đồ phải đặt TRƯỚC khi dựng MapWidget đầu tiên.
  if (AppEnvironment.hasMapbox) {
    MapboxOptions.setAccessToken(AppEnvironment.mapboxToken);
  } else {
    logger.w(
      'Chưa có MAPBOX_TOKEN — bản đồ sẽ hiện ô trống. '
      'Chạy lại với: flutter run --dart-define=MAPBOX_TOKEN=pk.xxx',
    );
  }

  runApp(const App());
}
