import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const platform = MethodChannel('com.example.ble_music_info/music_info');

void startBackgroundService() {
  if (Platform.isAndroid) {
    try {
      platform.invokeMethod('startMediaSessionService');
    } on PlatformException catch (e) {
      debugPrint("Failed to start service: '${e.message}'.");
    }
  }
}

void stopBackgroundService() {
  if (Platform.isAndroid) {
    try {
      platform.invokeMethod('stopMediaSessionService');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop service: '${e.message}'.");
    }
  }
}
