import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:music_info/utils/utils.dart';
import 'package:music_info/widgets/characteristic_tile.dart';
import 'package:music_info/widgets/descriptor_tile.dart';
import 'package:music_info/widgets/service_tile.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.device});

  final BluetoothDevice device;

  @override
  DeviceScreenState createState() => DeviceScreenState();
}

class DeviceScreenState extends State<DeviceScreen> {
  String musicInfo = "None";

  @override
  void initState() {
    super.initState();
    _loadMusicInfo();
  }

  Future<void> _loadMusicInfo() async {
    try {
      final String result = await BLEUtils.getMusicInfo();
      if (mounted) {
        setState(() {
          musicInfo = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          musicInfo = "Error retrieving music info: $e";
        });
      }
    }
  }

  Future<void> _sendMusicInfo() async {
    try {
      await BLEUtils.sendMusicInfo(widget.device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Music info sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending music info: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothConnectionState>(
              stream: widget.device.connectionState,
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
              stream: widget.device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: const Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
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
            ListTile(
              title: const Text('Music Info'),
              subtitle: Text(musicInfo),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendMusicInfo,
              child: const Text('Send Music Info'),
            ),
          ],
        ),
      ),
    );
  }
}
