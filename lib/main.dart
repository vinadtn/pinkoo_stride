import 'app/config/app_environment.dart';
import 'bootstrap.dart';

/// Entry point mặc định (`flutter run`) → chạy môi trường dev.
Future<void> main() => bootstrap(AppEnvironment.dev);
