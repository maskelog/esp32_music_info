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
import android.content.pm.PackageManager
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

    private var connectedDevice: BluetoothDevice? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var musicInfo: String = "None"

    private val musicInfoReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val musicInfo = intent.getStringExtra("music_info") ?: "None"
            println("Broadcast received: $musicInfo") // 디버그 로그 추가
            sendMusicInfoToBLE(musicInfo)
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
                else -> result.notImplemented()
            }
        }

        requestPermissions()
        registerReceiver(musicInfoReceiver, IntentFilter("com.example.ble_music_info.MUSIC_INFO"))
    }

    private fun requestPermissions() {
        runOnUiThread {
            // Request Bluetooth permissions
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) != PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {

                ActivityCompat.requestPermissions(this, arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN,
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT
                ), REQUEST_BLUETOOTH_PERMISSION)
            }

            // Request Location permissions
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {

                ActivityCompat.requestPermissions(this, arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ), REQUEST_LOCATION_PERMISSION)
            }

            // Request Notification Listener permissions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!isNotificationServiceEnabled()) {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
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
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    println("Bluetooth permission granted")
                } else {
                    println("Bluetooth permission denied")
                }
            }
            REQUEST_LOCATION_PERMISSION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    println("Location permission granted")
                } else {
                    println("Location permission denied")
                }
            }
        }
    }

    private fun sendMusicInfoToBLE(info: String) {
        val gattService = bluetoothGatt?.getService(java.util.UUID.fromString("3db02924-b2a6-4d47-be1f-0f90ad62a048"))
        val characteristic = gattService?.getCharacteristic(java.util.UUID.fromString("8d8218b6-97bc-4527-a8db-13094ac06b1d"))

        if (characteristic != null) {
            characteristic.value = info.toByteArray()
            bluetoothGatt?.writeCharacteristic(characteristic)
            println("BLE characteristic written: $info") // 디버그 로그 추가
        } else {
            println("Failed to find characteristic.") // 디버그 로그 추가
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

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(musicInfoReceiver)
    }
}
