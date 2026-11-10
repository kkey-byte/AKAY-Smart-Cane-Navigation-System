package com.example.app_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("akay_emergencies", "Cane emergency alerts", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Manual SOS and possible fall or impact alerts from linked navigators"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
