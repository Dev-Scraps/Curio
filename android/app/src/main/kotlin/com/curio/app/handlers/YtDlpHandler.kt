package com.curio.app.handlers

import android.content.Context
import android.util.Log
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.google.gson.Gson
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

/**
 * Handler for yt-dlp related method channel calls
 * Manages video information extraction, downloads, and metadata
 */
class YtDlpHandler(
    private val context: Context,
    private val backgroundScope: CoroutineScope,
    private val onProgress: (message: String, progress: Double) -> Unit
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "YtDlpHandler"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "getYtDlpVersion" -> getYtDlpVersion(result)
            "getVersion" -> getVersion(result)
            "getInfo" -> getInfo(call, result)
            "getEnhancedVideoInfo" -> getEnhancedVideoInfo(call, result)
            "getUserPlaylists" -> getUserPlaylists(call, result)
            "startDownload" -> startDownload(call, result)
            "startEnhancedDownload" -> startEnhancedDownload(call, result)
            "cancelEnhancedDownload" -> cancelEnhancedDownload(call, result)
            "get_formats_categorized" -> getFormatsCategorized(call, result)
            "getDownloadStatus" -> getDownloadStatus(call, result)
            "cancelDownload" -> cancelDownload(call, result)
            "getCookies" -> getCookies(call, result)
            "setPoToken" -> setPoToken(call, result)
            "downloadHighRes" -> downloadHighRes(call, result)
            "getHighResVideoInfo" -> getHighResVideoInfo(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getCookies(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        backgroundScope.launch {
            val cookieString = runCatching {
                val cm = android.webkit.CookieManager.getInstance()
                val cookies = cm.getCookie(url) ?: ""
                Log.d(TAG, "Retrieved ${cookies.length} chars of cookies for $url")
                cookies
            }.getOrElse { error ->
                Log.e(TAG, "Error getting cookies: ${error.message}")
                ""
            }
            withContext(Dispatchers.Main) {
                result.success(mapOf("cookies" to cookieString))
            }
        }
    }

    private fun initialize(result: MethodChannel.Result) {
        ensurePythonStarted()
        try {
            val py = Python.getInstance()
            val module = py.getModule("handlers.app_bridge")
            
            // FFmpeg path is now handled by FFmpegAssetExtractor in MainActivity
            // No need to pass it from here
            Log.d(TAG, "Initializing Python bridge")
            module.callAttr("init_ffmpeg", "")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init python bridge: ${e.message}")
        }
        result.success(null)
    }

    private fun getYtDlpVersion(result: MethodChannel.Result) {
        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                module.callAttr("get_ytdlp_version").toString()
            }.getOrElse { error -> errorJson(error) }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun getVersion(result: MethodChannel.Result) {
        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                val versionJson = module.callAttr("get_ytdlp_version").toString()
                val versionData = JSONObject(versionJson)
                if (versionData.getBoolean("error")) {
                    "unknown"
                } else {
                    versionData.getString("version")
                }
            }.getOrElse { error ->
                Log.e(TAG, "Error getting version: ${error.message}")
                "unknown"
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun getInfo(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val cookies = call.argument<String>("cookies")
        val flat = call.argument<Boolean>("flat") ?: false

        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "URL is required", null)
            return
        }

        backgroundScope.launch {
            val extractionMode = if (flat) "fast" else "full"
            onProgress("Fetching metadata ($extractionMode) for $url", 0.1)

            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                
                Log.d(TAG, "Calling extract_metadata (flat=$flat) for: $url")
                Log.d(TAG, "Cookies present: ${if (cookies.isNullOrEmpty()) "No" else "Yes (${cookies.length} chars)"}")
                
                onProgress("Processing with yt-dlp ($extractionMode mode)...", 0.5)
                
                val metadata = module.callAttr("extract_metadata", url, cookies, flat).toString()
                
                onProgress("Metadata fetched successfully", 1.0)
                metadata
            }.getOrElse { error ->
                Log.e(TAG, "Error in getInfo: ${error.message}", error)
                onProgress("Error: ${error.message}", -1.0)
                errorJson(error)
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun getEnhancedVideoInfo(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")

        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "URL is required", null)
            return
        }

        backgroundScope.launch {
            onProgress("Fetching enhanced video info for $url", 0.1)

            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                
                Log.d(TAG, "Calling getEnhancedVideoInfo for: $url")
                
                onProgress("Processing enhanced video info...", 0.5)
                
                val metadata = module.callAttr("getEnhancedVideoInfo", url).toString()
                
                onProgress("Enhanced video info fetched successfully", 1.0)
                metadata
            }.getOrElse { error ->
                Log.e(TAG, "Error in getEnhancedVideoInfo: ${error.message}", error)
                onProgress("Error: ${error.message}", -1.0)
                errorJson(error)
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun getUserPlaylists(call: MethodCall, result: MethodChannel.Result) {
        val cookies = call.argument<String>("cookies")

        backgroundScope.launch {
            onProgress("Fetching your playlists...", 0.1)

            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                
                Log.d(TAG, "Fetching user playlists")
                onProgress("Extracting playlist data...", 0.5)
                
                val playlists = module.callAttr("extract_user_playlists", cookies).toString()
                
                onProgress("Playlists loaded successfully", 1.0)
                playlists
            }.getOrElse { error ->
                Log.e(TAG, "Error fetching playlists: ${error.message}", error)
                onProgress("Error: ${error.message}", -1.0)
                errorJson(error)
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun startDownload(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val config = call.argument<Any>("config")

        if (url.isNullOrEmpty() || config == null) {
            result.error("INVALID_ARGS", "URL and config are required", null)
            return
        }

        backgroundScope.launch {
            try {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                Log.d(TAG, "Starting download for: $url")
                val configJson = buildConfigJson(config)
                val taskId = module.callAttr("start_download", url, configJson).toString()
                withContext(Dispatchers.Main) {
                    result.success(taskId)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error starting download: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("PYTHON_ERROR", "Python error in start_download: ${e.message}", e.toString())
                }
            }
        }
    }

    private fun startEnhancedDownload(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val arguments = call.arguments as? Map<String, Any>

        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "URL is required", null)
            return
        }

        backgroundScope.launch {
            val response = runCatching {
               
                Log.d(TAG, "Starting enhanced download - Native mode")
                
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                
                // Build config JSON from all arguments except url
                val configJson = buildConfigJson(arguments?.filterKeys { it != "url" })
                
                // Call the enhanced download function with url and config
                val taskId = module.callAttr("start_enhanced_download", url, configJson).toString()
                
                // Return success response as JSON string to match expected type
                """{"success": true, "taskId": "$taskId", "message": "Download started successfully"}"""
            }.getOrElse { error ->
                Log.e(TAG, "Error in startEnhancedDownload: ${error.message}", error)
                """{"success": false, "error": "${error.message}", "message": "Failed to start download"}"""
            }
            withContext(Dispatchers.Main) {
                result.success(response)
            }
        }
    }

    private fun cancelEnhancedDownload(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")
        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                val success = module.callAttr("cancel_download", taskId).toBoolean()
                """{"success": $success, "message": if (success) "Download cancelled successfully" else "Failed to cancel download"}"""
            }.getOrElse { error ->
                Log.e(TAG, "Error in cancelEnhancedDownload: ${error.message}", error)
                """{"success": false, "error": "${error.message}", "message": "Failed to cancel download"}"""
            }
            withContext(Dispatchers.Main) {
                result.success(response)
            }
        }
    }

    private fun getFormatsCategorized(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val cookies = call.argument<String>("cookies")

        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                module.callAttr("getInfo", url, cookies, false).toString()
            }.getOrElse { error -> errorJson(error) }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun getDownloadStatus(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")

        if (taskId == null) {
            result.error("INVALID_ARGS", "taskId is required", null)
            return
        }

        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                module.callAttr("get_download_status", taskId).toString()
            }.getOrElse { error ->
                Log.e(TAG, "Error getting status: ${error.message}", error)
                "{}"
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun cancelDownload(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")

        if (taskId == null) {
            result.error("INVALID_ARGS", "taskId is required", null)
            return
        }

        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                module.callAttr("cancel_download", taskId).toBoolean()
            }.getOrElse { error ->
                Log.e(TAG, "Error cancelling download: ${error.message}", error)
                false
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun ensurePythonStarted() {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(context))
        }
    }

    private fun setPoToken(call: MethodCall, result: MethodChannel.Result) {
        val token = call.argument<String>("token")
        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("handlers.app_bridge")
                module.callAttr("set_po_token", token ?: "").toString()
            }.getOrElse { error ->
                Log.e(TAG, "Error setting PO token: ${error.message}", error)
                errorJson(error)
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    private fun buildConfigJson(rawConfig: Any?): String {
        return when (rawConfig) {
            is Map<*, *> -> {
                val mutable = mutableMapOf<String, Any?>()
                rawConfig.forEach { (key, value) ->
                    if (key is String) {
                        mutable[key] = value
                    }
                }
                Gson().toJson(mutable)
            }
            is String -> {
                try {
                    JSONObject(rawConfig).toString()
                } catch (_: JSONException) {
                    JSONObject().toString()
                }
            }
            else -> {
                JSONObject().toString()
            }
        }
    }

    private fun errorJson(error: Throwable): String {
        val message = error.message?.replace("\"", "\\\"") ?: "Unknown error"
        return """{"error": true, "message": "$message"}"""
    }

    /**
     * Downloads a video in the highest available resolution (1080p+).
     * Uses yt_dlp_manager.py with FFmpeg for stream merging and QuickJS for signature validation.
     */
    private fun downloadHighRes(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val ffmpegPath = call.argument<String>("ffmpeg_path")
        val quickjsPath = call.argument<String>("quickjs_path")
        val outputDir = call.argument<String>("output_dir")
        val cookies = call.argument<String>("cookies")

        if (url.isNullOrEmpty() || ffmpegPath.isNullOrEmpty() || 
            quickjsPath.isNullOrEmpty() || outputDir.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "url, ffmpeg_path, quickjs_path, and output_dir are required", null)
            return
        }

        backgroundScope.launch {
            onProgress("Starting high-res download for $url", 0.1)

            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("yt_dlp_manager")
                
                Log.d(TAG, "Calling download_high_res with FFmpeg: $ffmpegPath, QuickJS: $quickjsPath")
                onProgress("Downloading with FFmpeg stream merging...", 0.3)
                
                // Call the Python convenience function
                val downloadResult = module.callAttr(
                    "download_high_res",
                    url,
                    ffmpegPath,
                    quickjsPath,
                    outputDir,
                    cookies ?: ""
                ).toString()
                
                onProgress("Download completed", 1.0)
                downloadResult
            }.getOrElse { error ->
                Log.e(TAG, "Error in downloadHighRes: ${error.message}", error)
                onProgress("Error: ${error.message}", -1.0)
                errorJson(error)
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }

    /**
     * Gets video information without downloading.
     * Useful for showing available formats before download.
     */
    private fun getHighResVideoInfo(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val ffmpegPath = call.argument<String>("ffmpeg_path")
        val quickjsPath = call.argument<String>("quickjs_path")
        val cookies = call.argument<String>("cookies")

        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "URL is required", null)
            return
        }

        backgroundScope.launch {
            val response = runCatching {
                ensurePythonStarted()
                val py = Python.getInstance()
                val module = py.getModule("yt_dlp_manager")
                
                // Create manager instance and call get_video_info
                val manager = module.callAttr(
                    "YtDlpManager",
                    ffmpegPath ?: "/data/data/com.curio.app/files/ffmpeg",
                    quickjsPath ?: "/data/data/com.curio.app/files/qjs"
                )
                
                val info = manager.callAttr("get_video_info", url, cookies ?: "")
                
                // Convert Python dict to JSON string
                val jsonModule = py.getModule("json")
                jsonModule.callAttr("dumps", info).toString()
            }.getOrElse { error ->
                Log.e(TAG, "Error in getHighResVideoInfo: ${error.message}", error)
                errorJson(error)
            }

            withContext(Dispatchers.Main) { result.success(response) }
        }
    }
}
