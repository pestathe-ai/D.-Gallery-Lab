package dev.dgallerylab.d_gallery_lab

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Canale "dgallerylab/archive":
 *  - sdkInt -> Int
 *  - requestWrite(ids) -> Boolean   (una conferma di sistema per tutto il blocco)
 *  - move(items: [{id, path}]) -> {moved: Int, failed: Int}
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dgallerylab/archive"
    private val writeRequestCode = 4711
    private var pendingWrite: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private fun uriOf(id: String): Uri =
        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toLong())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)

                    "hasAllFiles" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                            Environment.isExternalStorageManager()
                    )

                    "requestAllFiles" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                            } catch (e: Exception) {
                                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                            }
                        }
                        result.success(null)
                    }

                    "storageRoot" -> {
                        @Suppress("DEPRECATION")
                        result.success(Environment.getExternalStorageDirectory().absolutePath)
                    }

                    "requestWrite" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                            result.success(false); return@setMethodCallHandler
                        }
                        val ids = call.argument<List<String>>("ids") ?: emptyList()
                        if (ids.isEmpty()) { result.success(true); return@setMethodCallHandler }
                        if (pendingWrite != null) {
                            result.error("busy", "Richiesta già in corso", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val pi = MediaStore.createWriteRequest(contentResolver, ids.map { uriOf(it) })
                            pendingWrite = result
                            @Suppress("DEPRECATION")
                            startIntentSenderForResult(pi.intentSender, writeRequestCode, null, 0, 0, 0)
                        } catch (e: Exception) {
                            pendingWrite = null
                            result.error("write_request", e.message, null)
                        }
                    }

                    "move" -> {
                        val items = call.argument<List<Map<String, String>>>("items") ?: emptyList()
                        io.execute {
                            var moved = 0
                            var failed = 0
                            for (item in items) {
                                try {
                                    val values = ContentValues().apply {
                                        put(MediaStore.MediaColumns.RELATIVE_PATH, item["path"])
                                    }
                                    val n = contentResolver.update(uriOf(item["id"]!!), values, null, null)
                                    if (n > 0) moved++ else failed++
                                } catch (e: Exception) {
                                    failed++
                                }
                            }
                            main.post { result.success(mapOf("moved" to moved, "failed" to failed)) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == writeRequestCode) {
            val r = pendingWrite
            pendingWrite = null
            r?.success(resultCode == Activity.RESULT_OK)
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}
