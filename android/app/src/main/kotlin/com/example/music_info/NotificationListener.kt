package com.example.music_info

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        if (sbn.packageName == "com.google.android.apps.youtube.music") {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: "Unknown Title"
            val artist = extras.getString("android.text") ?: "Unknown Artist"

            val musicInfo = "$title - $artist"

            // Send the music info to Flutter
            val intent = Intent("com.example.music_info.MUSIC_INFO")
            intent.putExtra("music_info", musicInfo)
            sendBroadcast(intent)
        }
    }
}
