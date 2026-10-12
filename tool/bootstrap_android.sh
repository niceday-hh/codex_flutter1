#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
flutter create \
  --platforms=android \
  --org com.shiguang \
  --project-name smart_budget \
  --no-pub \
  "$TMP_DIR/smart_budget"
rm -rf android
cp -a "$TMP_DIR/smart_budget/android" ./android

MAIN_ACTIVITY="android/app/src/main/kotlin/com/shiguang/smart_budget/MainActivity.kt"
mkdir -p "$(dirname "$MAIN_ACTIVITY")"
cat > "$MAIN_ACTIVITY" <<'KOTLIN'
package com.shiguang.smart_budget

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {
    private val storageExecutor = Executors.newSingleThreadExecutor()
    private val channelName = "smart_budget/storage"
    private val requestSaveCsv = 4101
    private val requestPickCsv = 4102
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingCsvContent: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.attributes = window.attributes.apply {
            preferredRefreshRate = 120f
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "load", "loadCalendar" -> storageExecutor.execute {
                    try {
                        val key = if (call.method == "load") "app_state" else "calendar_state"
                        val raw = getSharedPreferences("smart_budget", MODE_PRIVATE).getString(key, null)
                        runOnUiThread { result.success(raw) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("READ_FAILED", error.message, null) }
                    }
                }
                "save", "saveCalendar" -> {
                    val payload = call.arguments as? String
                    if (payload == null) {
                        result.error("INVALID_DATA", "Expected a JSON string", null)
                    } else storageExecutor.execute {
                        try {
                            val key = if (call.method == "save") "app_state" else "calendar_state"
                            val saved = getSharedPreferences("smart_budget", MODE_PRIVATE)
                                .edit().putString(key, payload).commit()
                            runOnUiThread {
                                if (saved) result.success(null)
                                else result.error("SAVE_FAILED", "Cache was not saved", null)
                            }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("SAVE_FAILED", error.message, null) }
                        }
                    }
                }
                "saveCsv" -> {
                    if (pendingSaveResult != null) {
                        result.error("BUSY", "Another save request is active", null)
                        return@setMethodCallHandler
                    }
                    val args = call.arguments as? Map<*, *>
                    val filename = args?.get("filename") as? String ?: "拾光账本.csv"
                    val content = args?.get("content") as? String
                    if (content == null) {
                        result.error("INVALID_DATA", "Missing CSV content", null)
                        return@setMethodCallHandler
                    }
                    pendingSaveResult = result
                    pendingCsvContent = content
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/csv"
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    startActivityForResult(intent, requestSaveCsv)
                }
                "pickCsv" -> {
                    if (pendingPickResult != null) {
                        result.error("BUSY", "Another picker request is active", null)
                        return@setMethodCallHandler
                    }
                    pendingPickResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                            "text/csv",
                            "text/comma-separated-values",
                            "text/tab-separated-values",
                            "text/plain",
                            "application/vnd.ms-excel"
                        ))
                    }
                    startActivityForResult(intent, requestPickCsv)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        storageExecutor.shutdown() // Allow queued writes to finish.
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            requestSaveCsv -> {
                val result = pendingSaveResult
                pendingSaveResult = null
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    pendingCsvContent = null
                    result?.success(false)
                    return
                }
                try {
                    val uri = data.data!!
                    val bytes = (pendingCsvContent ?: "").toByteArray(Charsets.UTF_8)
                    contentResolver.openOutputStream(uri)?.use { output ->
                        output.write(bytes)
                        output.flush()
                    } ?: throw IllegalStateException("Unable to open output stream")
                    result?.success(true)
                } catch (error: Exception) {
                    result?.error("SAVE_FAILED", error.message, null)
                } finally {
                    pendingCsvContent = null
                }
            }
            requestPickCsv -> {
                val result = pendingPickResult
                pendingPickResult = null
                if (resultCode != Activity.RESULT_OK || data?.data == null) {
                    result?.success(null)
                    return
                }
                try {
                    val uri = data.data!!
                    val text = contentResolver.openInputStream(uri)?.use { input ->
                        input.bufferedReader(Charsets.UTF_8).readText()
                    } ?: throw IllegalStateException("Unable to open input stream")
                    result?.success(text)
                } catch (error: Exception) {
                    result?.error("READ_FAILED", error.message, null)
                }
            }
        }
    }
}
KOTLIN

python3 tool/generate_launcher_icons.py --res android/app/src/main/res

MANIFEST="android/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
s = s.replace('android:label="smart_budget"', 'android:label="拾光账本"')
if 'android:hardwareAccelerated=' not in s:
    s = s.replace('<application\n', '<application\n        android:hardwareAccelerated="true"\n')
p.write_text(s)
PY

echo "Android host prepared."


