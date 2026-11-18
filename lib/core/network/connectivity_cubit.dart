import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'network_info.dart';

enum NetworkStatus { unknown, online, offline }

/// Theo dõi trạng thái mạng cho toàn app (dùng bởi NetworkStatusBanner).
class ConnectivityCubit extends Cubit<NetworkStatus> {
  ConnectivityCubit(NetworkInfo networkInfo) : super(NetworkStatus.unknown) {
    _subscription = networkInfo.onStatusChange.listen(
      (connected) => emit(connected ? NetworkStatus.online : NetworkStatus.offline),
    );
  }

  late final StreamSubscription<bool> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
