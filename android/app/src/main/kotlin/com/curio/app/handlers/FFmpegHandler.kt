package com.curio.app.handlers

import android.content.Context
import android.util.Log
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Executes FFmpeg/FFprobe commands using binaries extracted into app storage.
 * Uses the system linker to avoid Android 16 noexec/W^X restrictions.
 */
object FFmpegHandler {
    private const val TAG = "FFmpegHandler"
    private var appContext: Context? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    private fun resolveBinary(context: Context, name: String): String? {
        val primary = File(context.filesDir, name)
        if (primary.exists()) {
            primary.setExecutable(true, false)
            return primary.absolutePath
        }
        return null
    }

    private fun resolveLinker(): String {
        val linker64 = File("/system/bin/linker64")
        return if (linker64.exists()) linker64.absolutePath else "/system/bin/linker"
    }

    private fun splitCommand(command: String): List<String> {
        val tokens = mutableListOf<String>()
        val regex = Regex("\"([^\"]*)\"|(\\S+)")
        for (match in regex.findAll(command)) {
            val quoted = match.groups[1]?.value
            val plain = match.groups[2]?.value
            tokens.add(quoted ?: plain ?: "")
        }
        return tokens.filter { it.isNotEmpty() }
    }

    fun executeFFmpegCommand(command: String): Map<String, Any> {
        val context = appContext
            ?: return mapOf("success" to false, "returnCode" to -1, "output" to "", "error" to "FFmpegHandler not initialized")
        val ffmpegPath = resolveBinary(context, "ffmpeg")
        if (ffmpegPath == null) {
            return mapOf("success" to false, "returnCode" to -1, "output" to "", "error" to "FFmpeg binary not found")
        }

        val args = splitCommand(command)
        val linker = resolveLinker()
        val processArgs = mutableListOf(linker, ffmpegPath).apply { addAll(args) }

        return runProcess(processArgs)
    }

    fun getMediaInfo(filePath: String): String {
        val context = appContext ?: return "{}"
        val ffprobePath = resolveBinary(context, "ffprobe")
        if (ffprobePath == null) {
            return "{}"
        }

        val linker = resolveLinker()
        val processArgs = listOf(
            linker,
            ffprobePath,
            "-v",
            "quiet",
            "-print_format",
            "json",
            "-show_streams",
            "-show_format",
            filePath
        )

        val result = runProcess(processArgs)
        return if (result["success"] == true) {
            result["output"] as? String ?: "{}"
        } else {
            "{}"
        }
    }

    private fun runProcess(args: List<String>): Map<String, Any> {
        return try {
            val process = ProcessBuilder(args)
                .redirectErrorStream(false)
                .start()

            val finished = process.waitFor(60, TimeUnit.SECONDS)
            if (!finished) {
                process.destroy()
                return mapOf("success" to false, "returnCode" to -1, "output" to "", "error" to "FFmpeg timed out")
            }

            val output = process.inputStream.bufferedReader().readText()
            val error = process.errorStream.bufferedReader().readText()
            val returnCode = process.exitValue()

            mapOf(
                "success" to (returnCode == 0),
                "returnCode" to returnCode,
                "output" to output,
                "error" to error
            )
        } catch (e: Exception) {
            Log.e(TAG, "FFmpeg execution error", e)
            mapOf(
                "success" to false,
                "returnCode" to -1,
                "output" to "",
                "error" to (e.message ?: "Unknown error")
            )
        }
    }
}
