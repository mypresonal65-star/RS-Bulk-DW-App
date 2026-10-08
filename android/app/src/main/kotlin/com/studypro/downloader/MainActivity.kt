package com.studypro.downloader

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val TOOLS_CHANNEL = "com.studypro.downloader/tools"
    private val PLAYER_CHANNEL = "com.studypro.downloader/player"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Native Tools Channel (Library directory helper)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TOOLS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getNativeLibraryDir") {
                val nativeDir = applicationInfo.nativeLibraryDir
                result.success(nativeDir)
            } else {
                result.notImplemented()
            }
        }

        // 2. Video Player Channel (Launches hardware-accelerated In-App Player)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playVideo") {
                try {
                    val mpdUrl = call.argument<String>("url") ?: ""
                    val title = call.argument<String>("title") ?: "Lecture"
                    val subject = call.argument<String>("subject") ?: ""
                    val batchName = call.argument<String>("batch") ?: ""
                    val keysRaw = call.argument<List<*>>("keys") ?: emptyList<Any>()
                    val keysList = ArrayList(keysRaw.map { it?.toString() ?: "" }.filter { it.isNotEmpty() })
                    val userAgent = call.argument<String>("userAgent") ?: ""
                    val cookie = call.argument<String>("cookie") ?: ""
                    val referer = call.argument<String>("referer") ?: "https://rarestudy.testuk.org/"

                    val intent = Intent(this, PlayerActivity::class.java).apply {
                        putExtra("mpdUrl", mpdUrl)
                        putExtra("title", title)
                        putExtra("subject", subject)
                        putExtra("batchName", batchName)
                        putStringArrayListExtra("keys", keysList)
                        putExtra("userAgent", userAgent)
                        putExtra("cookie", cookie)
                        putExtra("referer", referer)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("LAUNCH_ERROR", "Failed to launch video player: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
