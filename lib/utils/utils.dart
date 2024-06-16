import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BLEUtils {
  static const platform =
      MethodChannel('com.example.ble_music_info/music_info');

  // Method to get music info from native code
  static Future<Map<String, String>> getMusicInfo() async {
    try {
      final String? result =
          await platform.invokeMethod<String>('getMusicInfo');
      print("Music Info from Native: $result");

      if (result != null && result.isNotEmpty) {
        List<String> parts = result.split(' - ');
        if (parts.length == 2) {
          return {"title": parts[0], "artist": parts[1]};
        }
      }
      return {"title": "Unknown", "artist": "Unknown"};
    } catch (e) {
      print("Error retrieving music info: $e");
      return {"title": "Error", "artist": "Error retrieving music info: $e"};
    }
  }

  // Method to send music info to the connected BLE device
  static Future<void> sendMusicInfo(
      BluetoothDevice device, String musicInfo) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == '3db02924-b2a6-4d47-be1f-0f90ad62a048') {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                '8d8218b6-97bc-4527-a8db-13094ac06b1d') {
              await characteristic.write(utf8.encode(musicInfo),
                  withoutResponse: false);
              print("Music Info sent over BLE: $musicInfo");
            }
          }
        }
      }
    } catch (e) {
      print("Error sending music info: $e");
    }
  }

  // Method to monitor music info changes and send to BLE device
  static Future<void> monitorMusicInfo(BluetoothDevice device) async {
    String previousMusicInfo = "";

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      Map<String, String> currentMusicInfo = await getMusicInfo();
      String formattedMusicInfo =
          "${currentMusicInfo['title']} - ${currentMusicInfo['artist']}";
      if (formattedMusicInfo != previousMusicInfo &&
          currentMusicInfo['title'] != "Unknown" &&
          currentMusicInfo['artist'] != "Unknown") {
        previousMusicInfo = formattedMusicInfo;
        await sendMusicInfo(device, formattedMusicInfo);
      }
    });
  }

  // Method to send current time to the connected BLE device
  static Future<void> sendCurrentTime(BluetoothDevice device) async {
    try {
      final DateTime now = DateTime.now();
      final String currentTime =
          "${now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == '3db02924-b2a6-4d47-be1f-0f90ad62a048') {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                '8d8218b6-97bc-4527-a8db-13094ac06b1d') {
              await characteristic.write(currentTime.codeUnits,
                  withoutResponse: true);
              print("Current Time sent over BLE: $currentTime");
            }
          }
        }
      }
    } catch (e) {
      print("Error sending current time: $e");
    }
  }

  // Method to get available music players
  static Future<List<String>> getAvailablePlayers() async {
    try {
      final List<dynamic>? result =
          await platform.invokeMethod<List<dynamic>>('getAvailablePlayers');
      return result?.cast<String>() ?? [];
    } catch (e) {
      print("Error retrieving available players: $e");
      return [];
    }
  }

  // Method to select music player
  static Future<void> selectPlayer(String player) async {
    try {
      await platform.invokeMethod('selectPlayer', {"player": player});
    } catch (e) {
      print("Error selecting player: $e");
    }
  }
}

class StreamControllerReemit<T> {
  T? _latestValue;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  StreamControllerReemit({T? initialValue}) : _latestValue = initialValue;

  Stream<T> get stream {
    return _latestValue != null
        ? _controller.stream.newStreamWithInitialValue(_latestValue as T)
        : _controller.stream;
  }

  T? get value => _latestValue;

  void add(T newValue) {
    _latestValue = newValue;
    _controller.add(newValue);
  }

  Future<void> close() {
    return _controller.close();
  }
}

extension _StreamNewStreamWithInitialValue<T> on Stream<T> {
  Stream<T> newStreamWithInitialValue(T initialValue) {
    return transform(_NewStreamWithInitialValueTransformer(initialValue));
  }
}

class _NewStreamWithInitialValueTransformer<T>
    extends StreamTransformerBase<T, T> {
  final T initialValue;
  late StreamController<T> controller;
  late StreamSubscription<T> subscription;
  var listenerCount = 0;

  _NewStreamWithInitialValueTransformer(this.initialValue);

  @override
  Stream<T> bind(Stream<T> stream) {
    if (stream.isBroadcast) {
      return _bind(stream, broadcast: true);
    } else {
      return _bind(stream);
    }
  }

  Stream<T> _bind(Stream<T> stream, {bool broadcast = false}) {
    void onData(T data) {
      controller.add(data);
    }

    void onDone() {
      controller.close();
    }

    void onError(Object error) {
      controller.addError(error);
    }

    void onListen() {
      controller.add(initialValue);
      if (listenerCount == 0) {
        subscription = stream.listen(onData, onError: onError, onDone: onDone);
      }
      listenerCount++;
    }

    void onPause() {
      subscription.pause();
    }

    void onResume() {
      subscription.resume();
    }

    void onCancel() {
      listenerCount--;
      if (listenerCount == 0) {
        subscription.cancel();
        controller.close();
      }
    }

    if (broadcast) {
      controller =
          StreamController<T>.broadcast(onListen: onListen, onCancel: onCancel);
    } else {
      controller = StreamController<T>(
          onListen: onListen,
          onPause: onPause,
          onResume: onResume,
          onCancel: onCancel);
    }

    return controller.stream;
  }
}
