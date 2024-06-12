import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key, required this.device});

  final BluetoothDevice device;
  static const platform =
      MethodChannel('com.example.ble_music_info/music_info');

  Future<void> _sendMusicInfo(BluetoothCharacteristic characteristic) async {
    try {
      final String result = await platform.invokeMethod('getMusicInfo');
      List<int> bytes = result.codeUnits;
      await characteristic.write(bytes, withoutResponse: true);
    } catch (e) {
      print("Failed to send music info: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothConnectionState>(
              stream: device.connectionState,
              initialData: BluetoothConnectionState.connecting,
              builder: (c, snapshot) {
                if (snapshot.data == BluetoothConnectionState.connected) {
                  return const ListTile(
                    leading: Icon(Icons.bluetooth_connected),
                    title: Text('Connected'),
                    subtitle: Text('Device is connected'),
                  );
                }
                return const ListTile(
                  leading: Icon(Icons.bluetooth_disabled),
                  title: Text('Disconnected'),
                  subtitle: Text('Device is disconnected'),
                );
              },
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: const Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: const [],
              builder: (c, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: snapshot.data!.map((s) {
                    return ServiceTile(
                      service: s,
                      characteristicTiles: s.characteristics.map((c) {
                        return CharacteristicTile(
                          characteristic: c,
                          onReadPressed: () => c.read(),
                          onWritePressed: () async {
                            await c.write([0x12, 0x34]);
                            await c.read();
                          },
                          onNotificationPressed: () async {
                            await c.setNotifyValue(!c.isNotifying);
                            await c.read();
                          },
                          descriptorTiles: c.descriptors.map((d) {
                            return DescriptorTile(
                              descriptor: d,
                              onReadPressed: () => d.read(),
                              onWritePressed: () => d.write([0x12, 0x34]),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
            ),
            ElevatedButton(
              onPressed: () async {
                List<BluetoothService> services =
                    await device.discoverServices();
                for (BluetoothService service in services) {
                  if (service.uuid.toString() ==
                      "3db02924-b2a6-4d47-be1f-0f90ad62a048") {
                    for (BluetoothCharacteristic characteristic
                        in service.characteristics) {
                      if (characteristic.uuid.toString() ==
                          "8d8218b6-97bc-4527-a8db-13094ac06b1d") {
                        _sendMusicInfo(characteristic);
                      }
                    }
                  }
                }
              },
              child: const Text("Send Music Info"),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<Widget> characteristicTiles;

  const ServiceTile(
      {super.key, required this.service, required this.characteristicTiles});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('Service: ${service.uuid}'),
      children: characteristicTiles,
    );
  }
}

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;
  final VoidCallback? onNotificationPressed;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile({
    super.key,
    required this.characteristic,
    this.onReadPressed,
    this.onWritePressed,
    this.onNotificationPressed,
    required this.descriptorTiles,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: ListTile(
        title: const Text('Characteristic'),
        subtitle: Text(characteristic.uuid.toString()),
      ),
      children: <Widget>[
        TextButton(
          onPressed: onReadPressed,
          child: const Text('Read'),
        ),
        TextButton(
          onPressed: onWritePressed,
          child: const Text('Write'),
        ),
        TextButton(
          onPressed: onNotificationPressed,
          child: const Text('Notify'),
        ),
        ...descriptorTiles,
      ],
    );
  }
}

class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;

  const DescriptorTile({
    super.key,
    required this.descriptor,
    this.onReadPressed,
    this.onWritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Descriptor: ${descriptor.uuid}'),
      subtitle: Text(descriptor.value.toString()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onReadPressed != null)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: onReadPressed,
            ),
          if (onWritePressed != null)
            IconButton(
              icon: const Icon(Icons.file_upload),
              onPressed: onWritePressed,
            ),
        ],
      ),
    );
  }
}
