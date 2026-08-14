package com.senpwai.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "senpwai/update_installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath.isNullOrBlank()) {
                        result.error("invalid_path", "Missing prepared APK path.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        openApkInstaller(File(filePath))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("install_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openApkInstaller(apk: File) {
        require(apk.isFile) { "The prepared APK is missing." }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.update_provider",
            apk,
        )
        startActivity(
            Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = apkUri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                putExtra(Intent.EXTRA_RETURN_RESULT, false)
            },
        )
    }
}
