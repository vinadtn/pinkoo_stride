package com.wenemrtad.pinkoo.stride

import android.content.Context
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Đọc câu báo chặng bằng bộ TextToSpeech của máy.
 *
 * Tự viết thay vì dùng `flutter_tts`: thư viện đó vẫn `apply plugin:
 * 'kotlin-android'`, mà từ AGP 9 plugin đó bị bỏ nên cả app không build được.
 * Phần cần dùng chỉ là "đọc một câu", viết tay còn ngắn hơn đi vá thư viện.
 *
 * Bộ đọc khởi tạo mất vài trăm mili giây, nên câu tới trước lúc sẵn sàng được
 * giữ lại và đọc ngay sau khi init xong, chứ không nuốt mất.
 */
class SpeechPlugin(context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "pinkoo_stride/speech"
    }

    private var tts: TextToSpeech? = null
    private var ready = false
    private var available = false
    private var pending: String? = null

    init {
        tts = TextToSpeech(context.applicationContext) { status ->
            val engine = tts
            if (status == TextToSpeech.SUCCESS && engine != null) {
                val lang = engine.setLanguage(Locale("vi", "VN"))
                // Máy chưa cài gói tiếng Việt thì đọc giọng mặc định còn hơn im.
                if (lang == TextToSpeech.LANG_MISSING_DATA ||
                    lang == TextToSpeech.LANG_NOT_SUPPORTED
                ) {
                    engine.language = Locale.US
                }
                engine.setSpeechRate(0.95f)
                available = true
            }
            ready = true

            val queued = pending
            pending = null
            if (available && queued != null) speakNow(queued)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "speak" -> {
                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.error("BAD_ARGS", "Thiếu text", null)
                    return
                }
                when {
                    !ready -> pending = text
                    available -> speakNow(text)
                }
                result.success(ready && available)
            }

            "stop" -> {
                tts?.stop()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun speakNow(text: String) {
        // QUEUE_FLUSH: chặng mới tới thì bỏ câu cũ — đọc lại số liệu cũ chỉ gây nhiễu.
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "pinkoo-split")
    }

    fun dispose() {
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
