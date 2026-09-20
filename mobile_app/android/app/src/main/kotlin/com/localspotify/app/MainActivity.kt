package com.localspotify.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val DOWNLOAD_CHANNEL_ID = "localspotify_downloads"
    private val METHOD_CHANNEL = "com.localspotify.app/downloads"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val modes = display?.supportedModes
                val maxRefreshMode = modes?.maxByOrNull { it.refreshRate }
                if (maxRefreshMode != null && maxRefreshMode.refreshRate >= 90f) {
                    val params = window.attributes
                    params.preferredDisplayModeId = maxRefreshMode.modeId
                    window.attributes = params
                }
            } catch (_: Exception) {
                // Ignore if not supported on hardware
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateDownloadProgress" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: "Downloading track"
                    val artist = call.argument<String>("artist") ?: "LocalSpotify"
                    val progress = call.argument<Int>("progress") ?: 0
                    val isIndeterminate = call.argument<Boolean>("isIndeterminate") ?: false

                    showDownloadProgress(id, title, artist, progress, isIndeterminate)
                    result.success(true)
                }
                "completeDownload" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: "Downloaded track"
                    val artist = call.argument<String>("artist") ?: "LocalSpotify"

                    showDownloadComplete(id, title, artist)
                    result.success(true)
                }
                "cancelDownloadNotification" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelNotification(id)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Downloads"
            val descriptionText = "Offline Music Download Progress"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(DOWNLOAD_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showDownloadProgress(
        id: String,
        title: String,
        artist: String,
        progress: Int,
        isIndeterminate: Boolean
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = NotificationCompat.Builder(this, DOWNLOAD_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Downloading: $title")
            .setContentText(artist)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress.coerceIn(0, 100), isIndeterminate)

        notificationManager.notify(id.hashCode(), builder.build())
    }

    private fun showDownloadComplete(id: String, title: String, artist: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = NotificationCompat.Builder(this, DOWNLOAD_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Downloaded: $title")
            .setContentText("$artist • Saved offline")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .setProgress(0, 0, false)

        notificationManager.notify(id.hashCode(), builder.build())
    }

    private fun cancelNotification(id: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id.hashCode())
    }
}
