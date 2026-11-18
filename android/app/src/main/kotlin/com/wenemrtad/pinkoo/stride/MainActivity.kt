package com.wenemrtad.pinkoo.stride

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var speech: SpeechPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, StorySharePlugin.CHANNEL)
            .setMethodCallHandler(StorySharePlugin(this))

        val speechPlugin = SpeechPlugin(this)
        speech = speechPlugin
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SpeechPlugin.CHANNEL)
            .setMethodCallHandler(speechPlugin)
    }

    override fun onDestroy() {
        // Bộ đọc giữ tài nguyên của hệ thống — không shutdown là rò ra ngoài
        // vòng đời của màn hình.
        speech?.dispose()
        speech = null
        super.onDestroy()
    }
}
