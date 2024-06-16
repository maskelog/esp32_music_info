package com.example.music_info

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class MusicNotificationListenerService : NotificationListenerService() {

    companion object {
        var musicInfo: String? = "None"
    }

    private lateinit var mediaSessionManager: MediaSessionManager
    private val mediaSessionListener = MediaSessionListener()

    override fun onCreate() {
        super.onCreate()
        mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        mediaSessionManager.addOnActiveSessionsChangedListener(
            mediaSessionListener,
            ComponentName(this, MusicNotificationListenerService::class.java)
        )
        mediaSessionListener.onActiveSessionsChanged(
            mediaSessionManager.getActiveSessions(ComponentName(this, MusicNotificationListenerService::class.java))
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaSessionManager.removeOnActiveSessionsChangedListener(mediaSessionListener)
    }

    private inner class MediaSessionListener : MediaSessionManager.OnActiveSessionsChangedListener {
        override fun onActiveSessionsChanged(controllers: List<MediaController>?) {
            controllers?.forEach { controller ->
                controller.registerCallback(object : MediaController.Callback() {
                    override fun onMetadataChanged(metadata: MediaMetadata?) {
                        metadata?.let {
                            val title = it.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown Title"
                            val artist = it.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"
                            val newMusicInfo = "$title - $artist"

                            if (musicInfo != newMusicInfo) {
                                musicInfo = newMusicInfo
                                println("Music Info Updated: $newMusicInfo")

                                // Broadcast the music info to MainActivity
                                val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
                                intent.putExtra("music_info", newMusicInfo)
                                sendBroadcast(intent)
                            }
                        }
                    }
                })
                // Retrieve initial metadata
                val metadata = controller.metadata
                metadata?.let {
                    val title = it.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown Title"
                    val artist = it.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"
                    val newMusicInfo = "$title - $artist"

                    if (musicInfo != newMusicInfo) {
                        musicInfo = newMusicInfo
                        println("Music Info Updated: $newMusicInfo")

                        // Broadcast the music info to MainActivity
                        val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
                        intent.putExtra("music_info", newMusicInfo)
                        sendBroadcast(intent)
                    }
                }
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        super.onNotificationPosted(sbn)
        updateMusicInfoFromNotification(sbn)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        super.onNotificationRemoved(sbn)
        musicInfo = "None"
        val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
        intent.putExtra("music_info", musicInfo)
        sendBroadcast(intent)
    }

    private fun updateMusicInfoFromNotification(sbn: StatusBarNotification) {
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: "Unknown Title"
        val artist = extras.getString("android.text") ?: "Unknown Artist"
        val newMusicInfo = "$title - $artist"

        if (musicInfo != newMusicInfo) {
            musicInfo = newMusicInfo
            val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
            intent.putExtra("music_info", newMusicInfo)
            sendBroadcast(intent)
        }
    }
}
