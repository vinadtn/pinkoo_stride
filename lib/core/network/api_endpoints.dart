/// Đường dẫn API (tương đối với baseUrl trong AppEnvironment).
abstract final class ApiEndpoints {
  // Auth
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const changePassword = '/auth/change-password';

  // Push
  static const devices = '/devices';
  static String device(String token) => '/devices/${Uri.encodeComponent(token)}';

  // Posts
  static const posts = '/posts';
}
