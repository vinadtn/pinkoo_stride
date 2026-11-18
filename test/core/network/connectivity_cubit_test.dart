import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:pinkoo_stride/core/network/connectivity_cubit.dart';
import 'package:pinkoo_stride/core/network/network_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late _MockNetworkInfo networkInfo;
  late StreamController<bool> controller;

  setUp(() {
    networkInfo = _MockNetworkInfo();
    controller = StreamController<bool>();
    when(() => networkInfo.onStatusChange).thenAnswer((_) => controller.stream);
  });

  tearDown(() => controller.close());

  test('trạng thái ban đầu là unknown', () {
    expect(ConnectivityCubit(networkInfo).state, NetworkStatus.unknown);
  });

  blocTest<ConnectivityCubit, NetworkStatus>(
    'online → offline → online',
    build: () => ConnectivityCubit(networkInfo),
    act: (_) async {
      controller
        ..add(true)
        ..add(false)
        ..add(true);
    },
    expect: () => const [NetworkStatus.online, NetworkStatus.offline, NetworkStatus.online],
  );
}
