package com.example.music_info

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class MusicNotificationListenerService : NotificationListenerService() {
    companion object {
        var musicInfo: String? = "None"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        if (sbn.packageName == "com.google.android.apps.youtube.music") {
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: "Unknown Title"
            val artist = extras.getString("android.text") ?: "Unknown Artist"
            val newMusicInfo = "$title - $artist"

            if (musicInfo != newMusicInfo) {
                musicInfo = newMusicInfo

                // Debug log
                println("Music Info Updated: $musicInfo")

                // Broadcast the music info to MainActivityP
                val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
                intent.putExtra("music_info", musicInfo)
                sendBroadcast(intent)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        if (sbn.packageName == "com.google.android.apps.youtube.music") {
            // Reset music info when the notification is removed
            musicInfo = "None"

            // Broadcast the reset info to MainActivity
            val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
            intent.putExtra("music_info", musicInfo)
            sendBroadcast(intent)
        }
    }
}
