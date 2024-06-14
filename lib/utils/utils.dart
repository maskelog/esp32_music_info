import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BLEUtils {
  static const platform =
      MethodChannel('com.example.ble_music_info/music_info');

  // Method to get music info from native code
  static Future<String> getMusicInfo() async {
    try {
      final String result = await platform.invokeMethod('getMusicInfo');
      print("Music Info from Native: $result");
      return result;
    } catch (e) {
      return "Error retrieving music info: $e";
    }
  }

  // Method to send music info to the connected BLE device
  static Future<void> sendMusicInfo(BluetoothDevice device) async {
    try {
      final String result = await getMusicInfo();
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == '3db02924-b2a6-4d47-be1f-0f90ad62a048') {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                '8d8218b6-97bc-4527-a8db-13094ac06b1d') {
              await characteristic.write(result.codeUnits,
                  withoutResponse: true);
              print("Music Info sent over BLE: $result");
            }
          }
        }
      }
    } catch (e) {
      print("Error sending music info: $e");
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
      controller = StreamController<T>.broadcast(
        onListen: onListen,
        onCancel: onCancel,
      );
    } else {
      controller = StreamController<T>(
        onListen: onListen,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
      );
    }

    return controller.stream;
  }
}
