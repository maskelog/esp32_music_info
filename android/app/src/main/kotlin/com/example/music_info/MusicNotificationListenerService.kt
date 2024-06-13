package com.example.music_info

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent

class MusicNotificationListenerService : NotificationListenerService() {
    companion object {
        var musicInfo: String? = "None"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        if (sbn.packageName == "com.google.android.apps.youtube.music") {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title", "Unknown Title")
            val artist = extras.getString("android.text", "Unknown Artist")
            musicInfo = "$title - $artist"

            // Broadcast the music info to Flutter
            val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
            intent.putExtra("music_info", musicInfo)
            sendBroadcast(intent)
        }
    }
}
