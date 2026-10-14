package com.documentscannerpdfscanner_

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.system.Os
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "com.documentscannerpdfscanner_/downloads"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Early install in case camera init races during startup.
        CameraCrashProtector.install()
        super.onCreate(savedInstanceState)
        // Re-wrap after Flutter/Crashlytics handlers are attached.
        CameraCrashProtector.install(force = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // File I/O and MediaStore binder calls must not block Android rendering.
        MethodChannel(
            messenger,
            downloadsChannel,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        )
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val fileName = call.argument<String>("fileName")
                    val sourcePath = call.argument<String>("sourcePath")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (fileName.isNullOrBlank() || sourcePath.isNullOrBlank()) {
                        result.error("invalid_args", "fileName and sourcePath are required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedPath = saveToDownloads(fileName, File(sourcePath), mimeType)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("save_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(fileName: String, source: File, mimeType: String): String {
        require(source.isFile) { "Source file not found" }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Failed to create download entry")

            try {
                // A pending MediaStore row can resolve to the source file. Opening
                // it for write truncates the bytes before they can be copied.
                if (!isSameFile(uri, source)) {
                    resolver.openOutputStream(uri)?.use { output ->
                        source.inputStream().use { input -> input.copyTo(output) }
                    } ?: throw IllegalStateException("Failed to open download stream")
                }

                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                uri.toString()
            } catch (error: Exception) {
                // Do not leave a partial, pending download if copying fails.
                resolver.delete(uri, null, null)
                throw error
            }
        } else {
            val downloadsDir =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val outFile = File(downloadsDir, fileName)
            if (isSameFile(outFile, source)) {
                return outFile.absolutePath
            }
            FileOutputStream(outFile).use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
            }
            outFile.absolutePath
        }
    }

    private fun isSameFile(destination: File, source: File): Boolean {
        if (!destination.exists()) return false
        return try {
            destination.canonicalFile == source.canonicalFile
        } catch (error: Exception) {
            destination.absoluteFile == source.absoluteFile
        }
    }

    private fun isSameFile(destination: Uri, source: File): Boolean {
        return try {
            contentResolver.openFileDescriptor(destination, "r")?.use { descriptor ->
                val linked = File(Os.readlink("/proc/self/fd/${descriptor.fd}"))
                isSameFile(linked, source)
            } ?: false
        } catch (error: Exception) {
            false
        }
    }
}
