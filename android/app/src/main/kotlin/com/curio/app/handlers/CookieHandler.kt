package com.curio.app.handlers

import android.content.Context
import android.util.Log
import android.webkit.CookieManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Handler for cookie-related method channel calls
 * Manages WebView cookie retrieval and management
 */
class CookieHandler(
    private val context: Context,
    private val backgroundScope: CoroutineScope
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "CookieHandler"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCookies" -> getCookies(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Get cookies for a specific URL from WebView
     */
    private fun getCookies(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        
        backgroundScope.launch {
            val cookieString = runCatching {
                val cm = CookieManager.getInstance()
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
}
