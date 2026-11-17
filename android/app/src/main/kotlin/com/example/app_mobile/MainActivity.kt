package com.example.app_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.ActivityNotFoundException
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "akay/accessibility")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isScreenReaderEnabled" -> {
                        val manager = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
                        result.success(manager.getEnabledAccessibilityServiceList(
                            AccessibilityServiceInfo.FEEDBACK_SPOKEN
                        ).isNotEmpty())
                    }
                    "openAccessibilitySettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            result.success(null)
                        } catch (_: ActivityNotFoundException) {
                            result.error("unavailable", "Accessibility settings are unavailable", null)
                        } catch (_: SecurityException) {
                            result.error("unavailable", "Accessibility settings are restricted", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "akay/emergency")
            .setMethodCallHandler { call, result ->
                if (call.method == "playAlert") {
                    try {
                        val uri = android.media.RingtoneManager.getDefaultUri(
                            android.media.RingtoneManager.TYPE_NOTIFICATION
                        )
                        android.media.RingtoneManager.getRingtone(applicationContext, uri)?.play()
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("unavailable", "Alert sound is unavailable", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("akay_emergencies", "Cane emergency alerts", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Manual SOS and possible fall or impact alerts from linked navigators"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
