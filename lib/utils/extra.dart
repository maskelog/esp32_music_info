import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'utils.dart';

final Map<DeviceIdentifier, StreamControllerReemit<bool>> _cglobal = {};
final Map<DeviceIdentifier, StreamControllerReemit<bool>> _dglobal = {};

extension Extra on BluetoothDevice {
  StreamControllerReemit<bool> get _cstream {
    _cglobal[remoteId] ??= StreamControllerReemit(initialValue: false);
    return _cglobal[remoteId]!;
  }

  StreamControllerReemit<bool> get _dstream {
    _dglobal[remoteId] ??= StreamControllerReemit(initialValue: false);
    return _dglobal[remoteId]!;
  }

  Stream<bool> get isConnecting {
    return _cstream.stream;
  }

  Stream<bool> get isDisconnecting {
    return _dstream.stream;
  }

  Future<void> connectAndUpdateStream() async {
    _cstream.add(true);
    try {
      await connect(timeout: const Duration(seconds: 10));
    } finally {
      _cstream.add(false);
    }
  }

  Future<void> disconnectAndUpdateStream({bool queue = true}) async {
    _dstream.add(true);
    try {
      await disconnect(queue: queue);
    } finally {
      _dstream.add(false);
    }
  }
}
