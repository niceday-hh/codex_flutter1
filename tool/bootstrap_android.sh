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

@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {
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
            val prefs = getSharedPreferences("smart_budget", MODE_PRIVATE)
            when (call.method) {
                "load" -> result.success(prefs.getString("app_state", null))
                "save" -> {
                    val payload = call.arguments as? String
                    if (payload == null) {
                        result.error("INVALID_DATA", "Expected a JSON string", null)
                    } else {
                        prefs.edit().putString("app_state", payload).apply()
                        result.success(null)
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

mkdir -p android/app/src/main/res/drawable \
         android/app/src/main/res/mipmap-anydpi-v26 \
         android/app/src/main/res/values
cat > android/app/src/main/res/values/smart_budget_colors.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="smart_budget_icon_bg">#FFF5E4</color>
</resources>
XML
cat > android/app/src/main/res/drawable/ic_smart_budget_foreground.xml <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#F2A722" android:pathData="M54,14 C75,14 92,31 92,54 C92,77 75,94 54,94 C31,94 14,77 14,54 C14,31 31,14 54,14 Z"/>
    <path android:fillColor="#1D2C38" android:pathData="M50,30 H58 V46 H73 V54 H58 V78 H50 V58 C44,64 38,68 31,72 L27,65 C36,60 44,52 50,43 Z"/>
    <path android:fillColor="#FFFFFF" android:pathData="M68,28 C75,27 80,31 82,37 C75,39 69,37 66,32 Z"/>
</vector>
XML
cat > android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/smart_budget_icon_bg" />
    <foreground android:drawable="@drawable/ic_smart_budget_foreground" />
</adaptive-icon>
XML

MANIFEST="android/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace('android:label="smart_budget"', 'android:label="拾光账本"')
if 'android:hardwareAccelerated=' not in s:
    s = s.replace('<application\n', '<application\n        android:hardwareAccelerated="true"\n')
p.write_text(s)
PY

echo "Android host prepared."
