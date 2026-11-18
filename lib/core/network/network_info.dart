import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Trạng thái Internet THẬT, không chỉ "có bật Wi-Fi/4G".
///
/// - `connectivity_plus` báo ngay khi bật/tắt Wi-Fi, 4G → kích hoạt kiểm tra tức thì.
/// - `internet_connection_checker_plus` gửi request thử tới vài máy chủ
///   (định kỳ [checkInterval]) để biết có ra được Internet hay không.
abstract interface class NetworkInfo {
  Stream<bool> get onStatusChange;
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl({Duration checkInterval = const Duration(seconds: 5)})
    : _checker = InternetConnection.createInstance(
        checkInterval: checkInterval,
        triggerStream: Connectivity().onConnectivityChanged,
      );

  final InternetConnection _checker;

  @override
  Stream<bool> get onStatusChange =>
      _checker.onStatusChange.map((s) => s == InternetStatus.connected).distinct();

  @override
  Future<bool> get isConnected => _checker.hasInternetAccess;
}
