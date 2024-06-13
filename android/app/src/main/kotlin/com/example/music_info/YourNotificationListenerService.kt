package com.example.music_info

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class YourNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn?.notification?.let { notification ->
            val extras = notification.extras
            val title = extras.getString("android.title")
            val text = extras.getCharSequence("android.text").toString()
            val packageName = sbn.packageName

            if (packageName == "com.google.android.apps.youtube.music") {
                val musicInfo = "$title - $text"
                val intent = Intent("com.example.music_info.MUSIC_INFO")
                intent.putExtra("music_info", musicInfo)
                sendBroadcast(intent)
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        println("Notification Listener Connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        println("Notification Listener Disconnected")
    }
}
