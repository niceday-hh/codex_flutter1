package com.shiguang.smart_budget

import android.app.Activity
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

// Large ONNX assets are copied with bounded buffers on a background executor.
class VoiceAssets(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "smart_budget/voice")
        channel!!.setMethodCallHandler { call, result ->
            // Fast recording setup bypasses the model extraction executor.
            if (call.method == "recordDirectory") {
                try {
                    val records = File(activity.cacheDir, "voice-recordings")
                    check(records.exists() || records.mkdirs())
                    result.success(records.absolutePath)
                } catch (error: Exception) {
                    result.error("VOICE_RECORD_DIRECTORY_FAILED", error.message, null)
                }
                return@setMethodCallHandler
            }
            if (call.method != "prepare") { result.notImplemented(); return@setMethodCallHandler }
            executor.execute {
                try {
                    val metadata = activity.assets.open("voice/model.json").bufferedReader().use { JSONObject(it.readText()) }
                    val folder = File(activity.noBackupFilesDir, "paraformer-zh-${metadata.getString("sha256").take(12)}")
                    check(folder.exists() || folder.mkdirs()) { "Cannot create voice model directory" }
                    for (name in listOf("model.int8.onnx", "tokens.txt")) {
                        val file = File(folder, name)
                        val size = metadata.getJSONObject("sizes").getLong(name)
                        if (!file.exists() || file.length() != size) {
                            val temporary = File(folder, "$name.part")
                            try {
                                activity.assets.open("voice/$name").use { input ->
                                    temporary.outputStream().use { output -> input.copyTo(output, 65536) }
                                }
                                check(temporary.length() == size) { "Incomplete voice model" }
                                check(temporary.renameTo(file)) { "Cannot finish voice model extraction" }
                            } finally { temporary.delete() }
                        }
                    }
                    val records = File(activity.cacheDir, "voice-recordings")
                    check(records.exists() || records.mkdirs())
                    // Only abandoned private recordings are removed, never ledger data.
                    records.listFiles()?.filter { it.lastModified() < System.currentTimeMillis() - 3600000L }?.forEach { it.delete() }
                    val paths = mapOf("model" to File(folder, "model.int8.onnx").absolutePath,
                        "tokens" to File(folder, "tokens.txt").absolutePath, "recordDir" to records.absolutePath)
                    activity.runOnUiThread { result.success(paths) }
                } catch (error: Exception) {
                    activity.runOnUiThread { result.error("VOICE_MODEL_FAILED", error.message, null) }
                }
            }
        }
    }
    fun close() { channel?.setMethodCallHandler(null); executor.shutdown() }
}

