package com.curio.app

import android.content.Context
import java.io.File
import java.io.InputStream

object QuickJSExtractor {
    fun extractQuickJS(context: Context): String? {
        val targetDir = File(context.getFilesDir(), ".")
        val targetFile = File(targetDir, "qjs")
        
        // If already extracted, return path
        if (targetFile.exists() && targetFile.canExecute()) {
            return targetFile.absolutePath
        }
        
        return try {
            // Try to extract from assets
            val assetManager = context.assets
            val inputStream: InputStream = assetManager.open("qjs")
            
            targetFile.writeBytes(inputStream.readBytes())
            inputStream.close()
            
            // Set executable permissions
            targetFile.setExecutable(true, false)
            
            if (targetFile.canExecute()) {
                targetFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
