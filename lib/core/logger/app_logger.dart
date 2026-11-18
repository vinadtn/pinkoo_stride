import 'package:logger/logger.dart';

class AppLogger {
  AppLogger({required bool enabled})
    : _logger = Logger(
        level: enabled ? Level.debug : Level.off,
        printer: PrettyPrinter(methodCount: 0, errorMethodCount: 6),
      );

  final Logger _logger;

  void d(Object? message) => _logger.d(message);
  void i(Object? message) => _logger.i(message);
  void w(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);
  void e(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
