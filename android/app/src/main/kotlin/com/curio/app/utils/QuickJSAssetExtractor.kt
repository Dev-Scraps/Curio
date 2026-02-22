package com.curio.app.utils

import android.content.Context
import android.util.Log
import android.os.Build
import java.io.File
import java.io.FileOutputStream

object QuickJSAssetExtractor {
    private const val TAG = "QuickJSAssetExtractor"
    
    fun extractQuickJSBinary(context: Context): String? {
        // Detect device architecture
        val arch = getCurrentArchitecture()
        Log.d(TAG, "Detected architecture: $arch")
        
        // Extract QuickJS for the detected architecture
        return extractAsset(context, "quickjs/$arch/qjs", "qjs")
    }
    
    private fun getCurrentArchitecture(): String {
        return when (Build.SUPPORTED_ABIS.firstOrNull()) {
            "arm64-v8a" -> "arm64-v8a"
            "armeabi-v7a" -> "armeabi-v7a"
            "x86" -> "x86"
            "x86_64" -> "x86_64"
            else -> "arm64-v8a" // Default fallback
        }
    }
    
    private fun extractAsset(context: Context, assetPath: String, outputName: String): String? {
        return try {
            val outputFile = File(context.filesDir, outputName)
            
            // Only extract if not already exists
            if (outputFile.exists()) {
                Log.d(TAG, "$outputName already exists at: ${outputFile.absolutePath}")
                // Always ensure executable permissions are set
                outputFile.setExecutable(true, false)
                return outputFile.absolutePath
            }
            
            // Extract from assets
            context.assets.open(assetPath).use { inputStream ->
                FileOutputStream(outputFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            
            // Make executable
            outputFile.setExecutable(true)
            
            Log.d(TAG, "Extracted $outputName from assets to: ${outputFile.absolutePath}")
            outputFile.absolutePath
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract $outputName from assets", e)
            null
        }
    }
    
    fun getQuickJSPath(context: Context): String? {
        val quickjsFile = File(context.filesDir, "qjs")
        return if (quickjsFile.exists()) {
            quickjsFile.absolutePath
        } else {
            null
        }
    }
}
