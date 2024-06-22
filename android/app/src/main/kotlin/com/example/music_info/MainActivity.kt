package com.example.music_info

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ble_music_info/music_info"
    private val REQUEST_BLUETOOTH_PERMISSION = 1
    private val REQUEST_LOCATION_PERMISSION = 2
    private val REQUEST_NOTIFICATION_PERMISSION = 3
    private val PREFERENCES_NAME = "music_info_preferences"
    private val PREFERENCE_SELECTED_APP = "selected_app"

    private var connectedDevice: BluetoothDevice? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var musicInfo: String = "None"
    private var lastSentMusicInfo: String = ""

    private val musicInfoReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val newMusicInfo = intent.getStringExtra("music_info") ?: "None"
            if (newMusicInfo != musicInfo) {
                musicInfo = newMusicInfo
                println("Broadcast received: $musicInfo")
                sendMusicInfoToBLE(musicInfo)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMusicInfo" -> {
                    result.success(musicInfo)
                }
                "getConnectedDevice" -> {
                    result.success(connectedDevice?.address ?: "None")
                }
                "getAvailablePlayers" -> {
                    result.success(getAvailableMusicPlayers())
                }
                "selectPlayer" -> {
                    val player = call.argument<String>("player")
                    if (player != null) {
                        saveSelectedPlayer(player)
                        result.success(null)
                    } else {
                        result.error("UNAVAILABLE", "Player not available.", null)
                    }
                }
                "startMediaSessionService" -> {
                    startMediaSessionService()
                    result.success(null)
                }
                "stopMediaSessionService" -> {
                    stopMediaSessionService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        requestPermissions()
        registerReceiver(musicInfoReceiver, IntentFilter("com.example.ble_music_info.MUSIC_INFO"))
    }

    private fun startMediaSessionService() {
        val intent = Intent(this, MediaSessionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMediaSessionService() {
        val intent = Intent(this, MediaSessionService::class.java)
        stopService(intent)
    }

    private fun requestPermissions() {
        runOnUiThread {
            val bluetoothPermissions = arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
            val locationPermissions = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )

            // Request Bluetooth permissions
            if (!bluetoothPermissions.all {
                    ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
                }) {
                ActivityCompat.requestPermissions(this, bluetoothPermissions, REQUEST_BLUETOOTH_PERMISSION)
            }

            // Request Location permissions
            if (!locationPermissions.all {
                    ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
                }) {
                ActivityCompat.requestPermissions(this, locationPermissions, REQUEST_LOCATION_PERMISSION)
            }

            // Request Notification Listener permissions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!isNotificationServiceEnabled()) {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivityForResult(intent, REQUEST_NOTIFICATION_PERMISSION)
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = ComponentName(this, MusicNotificationListenerService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_BLUETOOTH_PERMISSION -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    println("Bluetooth permission granted")
                } else {
                    println("Bluetooth permission denied")
                }
            }
            REQUEST_LOCATION_PERMISSION -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    println("Location permission granted")
                } else {
                    println("Location permission denied")
                }
            }
        }
    }

    private fun getAvailableMusicPlayers(): List<String> {
        val musicApps = mutableListOf<String>()
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_APP_MUSIC)
        val pm: PackageManager = packageManager
        val apps: List<ResolveInfo> = pm.queryIntentActivities(intent, 0)
        for (app in apps) {
            val appName = app.loadLabel(pm).toString()
            musicApps.add(appName)
        }
        return musicApps
    }

    private fun saveSelectedPlayer(player: String) {
        val prefs: SharedPreferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        with(prefs.edit()) {
            putString(PREFERENCE_SELECTED_APP, player)
            apply()
        }
    }

    private fun getSelectedPlayer(): String? {
        val prefs: SharedPreferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        return prefs.getString(PREFERENCE_SELECTED_APP, null)
    }

    // BLE 디바이스 연결 상태 처리
    private fun onDeviceConnected(deviceAddress: String) {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        val device = bluetoothAdapter.getRemoteDevice(deviceAddress)
        connectedDevice = device
        bluetoothGatt = device.connectGatt(this, false, gattCallback)
    }

    private fun onDeviceDisconnected() {
        connectedDevice = null
        bluetoothGatt?.close()
        bluetoothGatt = null
    }

    private fun sendMusicInfoToBLE(info: String) {
        if (info != lastSentMusicInfo) {
            val gattService = bluetoothGatt?.getService(java.util.UUID.fromString("3db02924-b2a6-4d47-be1f-0f90ad62a048"))
            val characteristic = gattService?.getCharacteristic(java.util.UUID.fromString("8d8218b6-97bc-4527-a8db-13094ac06b1d"))

            if (characteristic != null) {
                val formattedInfo = formatMusicInfo(info)
                characteristic.value = formattedInfo.toByteArray()
                bluetoothGatt?.writeCharacteristic(characteristic)
                println("BLE characteristic written: $formattedInfo") // Debug log
                lastSentMusicInfo = formattedInfo
            } else {
                println("Failed to find characteristic.") // Debug log
            }
        }
    }

    private fun formatMusicInfo(info: String): String {
        val delimiterIndex = info.indexOf(" - ")
        return if (delimiterIndex != -1 && delimiterIndex < info.length - 3) {
            val artist = info.substring(0, delimiterIndex)
            val title = info.substring(delimiterIndex + 3)
            "$artist - $title"
        } else {
            info
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothGatt.STATE_CONNECTED) {
                println("Connected to GATT server.")
                gatt.discoverServices()
            } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                println("Disconnected from GATT server.")
                bluetoothGatt?.close()
                bluetoothGatt = null
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                println("Services discovered.")
            } else {
                println("Failed to discover services.")
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                println("Characteristic written successfully.")
            } else {
                println("Failed to write characteristic.")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(musicInfoReceiver)
    }
}
