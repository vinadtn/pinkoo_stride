import 'dart:async';

import 'package:flutter/foundation.dart';

/// Biến một Stream (vd `authCubit.stream`) thành Listenable cho `GoRouter.refreshListenable`.
class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
