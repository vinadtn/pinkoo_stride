import 'package:flutter/foundation.dart';

enum AppFlavor { dev, staging, prod }

/// Cấu hình theo môi trường. Mỗi file `main_<flavor>.dart` truyền vào một instance.
class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.appName,
    required this.baseUrl,
    required this.enableLogging,
  });

  final AppFlavor flavor;
  final String appName;
  final String baseUrl;
  final bool enableLogging;

  bool get isProd => flavor == AppFlavor.prod;

  static final dev = AppEnvironment(
    flavor: AppFlavor.dev,
    appName: 'Pinkoo Stride Dev',
    baseUrl: _apiBaseUrl(fallback: _localApiUrl),
    enableLogging: true,
  );

  static final staging = AppEnvironment(
    flavor: AppFlavor.staging,
    appName: 'Pinkoo Stride Staging',
    baseUrl: _apiBaseUrl(fallback: 'https://staging-api.example.com'), // TODO: API staging thật
    enableLogging: true,
  );

  static final prod = AppEnvironment(
    flavor: AppFlavor.prod,
    appName: 'Pinkoo Stride',
    baseUrl: _apiBaseUrl(fallback: 'https://api.example.com'), // TODO: API production thật
    enableLogging: false,
  );

  /// Ghi đè khi chạy: `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000`
  /// (cần khi chạy trên điện thoại thật cùng mạng LAN với máy chạy backend).
  static String _apiBaseUrl({required String fallback}) {
    const override = String.fromEnvironment('API_BASE_URL');
    return override.isNotEmpty ? override : fallback;
  }

  /// Backend chưa có — giữ sẵn chỗ cắm. Máy ảo Android không thấy `localhost`
  /// của máy tính → phải dùng 10.0.2.2.
  static String get _localApiUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  // ---------------------------------------------------------------- secrets --
  // Không hardcode vào repo. Truyền lúc chạy/build:
  //   flutter run --dart-define=MAPBOX_TOKEN=pk.xxx --dart-define=FB_APP_ID=123

  /// Public access token (`pk.*`) để render bản đồ và gọi Static Images API.
  /// Rỗng = chưa cấu hình → app hiện placeholder thay vì bản đồ.
  static const String mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get hasMapbox => mapboxToken.isNotEmpty;

  /// Facebook App ID — Instagram bắt buộc có để nhận intent ADD_TO_STORY.
  /// Rỗng = nút Story tự chuyển về share sheet hệ thống.
  static const String facebookAppId = String.fromEnvironment('FB_APP_ID');

  static bool get hasFacebookAppId => facebookAppId.isNotEmpty;
}
