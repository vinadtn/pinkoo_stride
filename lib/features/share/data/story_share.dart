import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/config/app_environment.dart';
import '../../../core/logger/app_logger.dart';

/// Kết quả của một lần bấm "Instagram Story".
enum StoryShareResult {
  /// Đã mở Instagram với ảnh làm nền story.
  openedInstagram,

  /// Chưa cấu hình Facebook App ID → đã mở chia sẻ thường thay thế.
  fellBackNoAppId,

  /// Máy chưa cài Instagram → đã mở chia sẻ thường thay thế.
  fellBackNotInstalled,

  /// Chỉ hỗ trợ Android ở bản này → đã mở chia sẻ thường.
  fellBackUnsupportedPlatform,
}

/// Đẩy ảnh thẳng sang Instagram Story, hoặc rơi về chia sẻ thường nếu không được.
///
/// Instagram **bắt buộc** có Facebook App ID trong extra `source_application`
/// của intent `com.instagram.share.ADD_TO_STORY` (quy định từ 30/11/2022);
/// thiếu nó thì Instagram mở lên rồi không nhận ảnh. Nên khi chưa cấu hình
/// `FB_APP_ID`, ở đây không thử intent nữa mà mở luôn hộp thoại chia sẻ hệ
/// thống — người dùng chọn Instagram → Story vẫn xong việc, chỉ thêm một bước.
class StoryShare {
  StoryShare({required this.logger});

  final AppLogger logger;

  static const _channel = MethodChannel('pinkoo_stride/story_share');

  Future<StoryShareResult> shareImage(Uint8List pngBytes, {String? caption}) async {
    final file = await _writePng(pngBytes);

    if (!Platform.isAndroid) {
      await _shareSheet(file, caption);
      return StoryShareResult.fellBackUnsupportedPlatform;
    }
    if (!AppEnvironment.hasFacebookAppId) {
      await _shareSheet(file, caption);
      return StoryShareResult.fellBackNoAppId;
    }

    try {
      final ok = await _channel.invokeMethod<bool>('shareToInstagramStory', {
        'imagePath': file.path,
        'appId': AppEnvironment.facebookAppId,
      });
      if (ok ?? false) return StoryShareResult.openedInstagram;
    } on PlatformException catch (e) {
      logger.w('Không mở được Instagram Story: ${e.code} ${e.message}');
    } on MissingPluginException catch (_) {
      logger.w('Chưa có phần native cho story_share — dùng chia sẻ thường');
    }

    await _shareSheet(file, caption);
    return StoryShareResult.fellBackNotInstalled;
  }

  /// Chia sẻ ảnh qua hộp thoại hệ thống (dùng được mọi nơi, mọi app).
  Future<ShareResult> shareImageSheet(Uint8List pngBytes, {String? caption}) async =>
      _shareSheet(await _writePng(pngBytes), caption);

  Future<ShareResult> _shareSheet(File file, String? caption) => SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: caption),
  );

  Future<File> _writePng(Uint8List bytes) async {
    // Cùng thư mục `share/` đã khai trong res/xml/story_share_paths.xml, nhờ đó
    // FileProvider cấp được quyền đọc cho Instagram.
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'pinkoo_story.png'));
    return file.writeAsBytes(bytes, flush: true);
  }
}
