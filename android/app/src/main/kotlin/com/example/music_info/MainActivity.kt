package com.example.music_info

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ble_music_info/music_info"
    private val REQUEST_MEDIA_CONTROL = 1
    private val REQUEST_BLUETOOTH_PERMISSIONS = 2

    @RequiresApi(Build.VERSION_CODES.M)
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMusicInfo") {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.MEDIA_CONTENT_CONTROL)
                    != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.MEDIA_CONTENT_CONTROL), REQUEST_MEDIA_CONTROL)
                } else {
                    val musicInfo = getMusicInfo()
                    if (musicInfo != null) {
                        result.success(musicInfo)
                    } else {
                        result.error("UNAVAILABLE", "Music information not available.", null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }

        requestBluetoothPermissions()
    }

    private fun requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val permissions = arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.POST_NOTIFICATIONS,
                Manifest.permission.SYSTEM_ALERT_WINDOW
            )
            ActivityCompat.requestPermissions(this, permissions, REQUEST_BLUETOOTH_PERMISSIONS)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_MEDIA_CONTROL) {
            if ((grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)) {
                val musicInfo = getMusicInfo()
                if (musicInfo != null) {
                    MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger
                        ?: throw IllegalStateException("BinaryMessenger is null"), CHANNEL).invokeMethod("getMusicInfo", musicInfo)
                }
            } else {
                println("Media control permission denied")
            }
        }

        if (requestCode == REQUEST_BLUETOOTH_PERMISSIONS) {
            if ((grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)) {
                // Permissions granted, do something
            } else {
                println("Bluetooth permissions denied")
            }
        }
    }

    private fun getMusicInfo(): String? {
        val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        val controllers = mediaSessionManager.getActiveSessions(null)

        if (controllers.isNotEmpty()) {
            val controller = controllers[0]
            val metadata = controller.metadata
            if (metadata != null) {
                val title = metadata.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: "Unknown Title"
                val artist = metadata.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: "Unknown Artist"
                return "$title - $artist"
            }
        }
        return null
    }
}
