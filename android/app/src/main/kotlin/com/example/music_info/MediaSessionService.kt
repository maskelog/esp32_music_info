package com.example.music_info

import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Build
import android.os.IBinder
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class MediaSessionService : Service() {

    private lateinit var mediaSessionManager: MediaSessionManager
    private lateinit var mediaController: MediaController

    override fun onCreate() {
        super.onCreate()
        mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        mediaSessionManager.addOnActiveSessionsChangedListener(
            MediaSessionListener(),
            ComponentName(this, MediaSessionService::class.java)
        )
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private inner class MediaSessionListener : MediaSessionManager.OnActiveSessionsChangedListener {
        override fun onActiveSessionsChanged(controllers: List<MediaController>?) {
            controllers?.forEach { controller ->
                controller.registerCallback(object : MediaController.Callback() {
                    override fun onMetadataChanged(metadata: android.media.MediaMetadata?) {
                        metadata?.let {
                            val title = it.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown Title"
                            val artist = it.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"
                            val album = it.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM) ?: "Unknown Album"
                            val newMusicInfo = "Title: $title\nArtist: $artist\nAlbum: $album"

                            if (newMusicInfo != MusicNotificationListenerService.musicInfo) {
                                MusicNotificationListenerService.musicInfo = newMusicInfo
                                println("Music Info Updated: $newMusicInfo")

                                // Broadcast the music info to MainActivity
                                val intent = Intent("com.example.ble_music_info.MUSIC_INFO")
                                intent.putExtra("music_info", newMusicInfo)
                                sendBroadcast(intent)
                            }
                        }
                    }
                })
            }
        }
    }
}
