import 'package:flutter_bloc/flutter_bloc.dart';

import '../logger/app_logger.dart';

/// Log mọi thay đổi state và lỗi của mọi Bloc/Cubit (chỉ hiện khi logging bật).
class AppBlocObserver extends BlocObserver {
  AppBlocObserver(this._logger);

  final AppLogger _logger;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _logger.d('${bloc.runtimeType}: ${change.currentState} → ${change.nextState}');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.e('${bloc.runtimeType} error', error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
