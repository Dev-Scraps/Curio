package com.curio.app.utils

import android.content.Context
import android.util.Log
import android.os.Build
import java.io.File
import java.io.FileOutputStream

object FFmpegAssetExtractor {
    private const val TAG = "FFmpegAssetExtractor"
    
    fun extractFFmpegBinaries(context: Context): Pair<String?, String?> {
        // Detect device architecture
        val arch = getCurrentArchitecture()
        Log.d(TAG, "Detected architecture: $arch")
        
        // Extract both ffmpeg and ffprobe for the detected architecture
        val ffmpegPath = extractAsset(context, "ffmpeg/$arch/ffmpeg", "ffmpeg")
        val ffprobePath = extractAsset(context, "ffmpeg/$arch/ffprobe", "ffprobe")
        
        return Pair(ffmpegPath, ffprobePath)
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
                // Always ensure executable permissions are set, even if file exists
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
    
    fun getFFmpegPath(context: Context): String? {
        val ffmpegFile = File(context.filesDir, "ffmpeg")
        return if (ffmpegFile.exists()) {
            ffmpegFile.absolutePath
        } else {
            null
        }
    }
    
    fun getFFprobePath(context: Context): String? {
        val ffprobeFile = File(context.filesDir, "ffprobe")
        return if (ffprobeFile.exists()) {
            ffprobeFile.absolutePath
        } else {
            null
        }
    }
}
