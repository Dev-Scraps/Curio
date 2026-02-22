package com.curio.app

import android.os.Bundle
import android.webkit.CookieManager
import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject
import android.os.Build
import com.curio.app.handlers.YtDlpHandler
import com.curio.app.handlers.CookieHandler
import com.curio.app.handlers.FFmpegHandler
import com.curio.app.utils.FFmpegAssetExtractor
import com.curio.app.utils.QuickJSAssetExtractor

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.curio.app.yt_dlp"
        private const val TAG = "MainActivity"
    }

    private val backgroundScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var progressEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        FFmpegHandler.initialize(applicationContext)

        backgroundScope.launch {
            try {
                // Extract FFmpeg binaries from assets
                val (ffmpegPath, ffprobePath) = FFmpegAssetExtractor.extractFFmpegBinaries(applicationContext)
                
                if (ffmpegPath != null) {
                    Log.d(TAG, "FFmpeg binary available at: $ffmpegPath")
                } else {
                    Log.w(TAG, "FFmpeg binary not found in assets - FFmpeg post-processing may not work")
                }
                
                if (ffprobePath != null) {
                    Log.d(TAG, "FFprobe binary available at: $ffprobePath")
                } else {
                    Log.w(TAG, "FFprobe binary not found in assets")
                }
                
                // Extract QuickJS binary from assets
                val quickjsPath = QuickJSAssetExtractor.extractQuickJSBinary(applicationContext)
                
                if (quickjsPath != null) {
                    Log.d(TAG, "QuickJS binary available at: $quickjsPath")
                } else {
                    Log.w(TAG, "QuickJS binary not found in assets - YouTube signature solving may not work")
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize FFmpeg/QuickJS", e)
            }
        }
    }

    private fun sendProgress(message: String, progress: Double) {
        backgroundScope.launch(Dispatchers.Main) {
            progressEventSink?.success(mapOf(
                "message" to message,
                "progress" to progress,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$CHANNEL_NAME/progress"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressEventSink = events
                Log.d(TAG, "Progress event channel listening")
            }

            override fun onCancel(arguments: Any?) {
                progressEventSink = null
                Log.d(TAG, "Progress event channel cancelled")
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(YtDlpHandler(this, backgroundScope) { message, progress ->
            sendProgress(message, progress)
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$CHANNEL_NAME/cookies",
        ).setMethodCallHandler(CookieHandler(this, backgroundScope))


    }
}
