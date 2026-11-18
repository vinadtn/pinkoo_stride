package com.wenemrtad.pinkoo.stride

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Đẩy một ảnh PNG sang Instagram Story bằng intent `com.instagram.share.ADD_TO_STORY`.
 *
 * Hai thứ bắt buộc, thiếu là Instagram mở lên rồi không nhận ảnh:
 *  - extra `source_application` = Facebook App ID (quy định từ 30/11/2022);
 *  - URI phải là content URI do FileProvider cấp, kèm FLAG_GRANT_READ_URI_PERMISSION.
 *
 * Phía Dart (`StoryShare`) tự rơi về hộp thoại chia sẻ hệ thống khi hàm này
 * trả về false, nên không có Instagram thì nút vẫn dùng được.
 */
class StorySharePlugin(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "pinkoo_stride/story_share"
        private const val ADD_TO_STORY = "com.instagram.share.ADD_TO_STORY"
        private const val INSTAGRAM_PACKAGE = "com.instagram.android"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "shareToInstagramStory") {
            result.notImplemented()
            return
        }

        val imagePath = call.argument<String>("imagePath")
        val appId = call.argument<String>("appId")
        if (imagePath.isNullOrBlank() || appId.isNullOrBlank()) {
            result.error("BAD_ARGS", "Thiếu imagePath hoặc appId", null)
            return
        }

        val file = File(imagePath)
        if (!file.exists()) {
            result.error("NO_FILE", "Không thấy file ảnh: $imagePath", null)
            return
        }

        try {
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.storyshare",
                file,
            )

            val intent = Intent(ADD_TO_STORY).apply {
                setDataAndType(uri, "image/png")
                setPackage(INSTAGRAM_PACKAGE)
                putExtra("source_application", appId)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // resolveActivity trả null khi chưa cài Instagram, hoặc khi quên khai
            // <queries> trong AndroidManifest (Android 11+).
            if (intent.resolveActivity(activity.packageManager) == null) {
                result.success(false)
                return
            }

            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("STORY_SHARE_FAILED", e.message, null)
        }
    }
}
