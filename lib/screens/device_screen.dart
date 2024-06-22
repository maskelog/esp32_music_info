import 'dart:async';
import 'dart:convert';
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
  String previousMusicInfo = "None";
  BluetoothCharacteristic? musicCharacteristic;

  @override
  void initState() {
    super.initState();
    _loadMusicInfo();
    _subscribeToCharacteristic();
    _getMusicInfoPeriodically();
  }

  Future<void> _loadMusicInfo() async {
    try {
      final Map<String, String> result = await BLEUtils.getMusicInfo();
      String newMusicInfo = "${result['title']} - ${result['artist']}";
      if (newMusicInfo != musicInfo && newMusicInfo != "Unknown - Unknown") {
        if (mounted) {
          setState(() {
            musicInfo = newMusicInfo;
            previousMusicInfo = newMusicInfo;
          });
          if (musicCharacteristic != null) {
            await _sendMusicInfo(newMusicInfo);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          musicInfo = "Error retrieving music info: $e";
        });
      }
    }
  }

  Future<void> _subscribeToCharacteristic() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == '3db02924-b2a6-4d47-be1f-0f90ad62a048') {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() ==
              '8d8218b6-97bc-4527-a8db-13094ac06b1d') {
            musicCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              String newMusicInfo = utf8.decode(value);
              if (newMusicInfo != musicInfo &&
                  newMusicInfo.contains(" - ") &&
                  newMusicInfo != "Unknown - Unknown") {
                setState(() {
                  musicInfo = newMusicInfo;
                  previousMusicInfo = newMusicInfo;
                });
              }
            });
          }
        }
      }
    }
  }

  Future<void> _sendMusicInfo(String info) async {
    if (musicCharacteristic != null) {
      await musicCharacteristic!.write(utf8.encode(info));
      print("Sent music info: $info");
    }
  }

  void _getMusicInfoPeriodically() {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _loadMusicInfo();
    });
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
                          onReadPressed: () async {
                            final value = await c.read();
                            setState(() {
                              musicInfo = utf8.decode(value); // UTF-8 디코딩 사용
                            });
                          },
                          onWritePressed: () async {
                            await BLEUtils.sendMusicInfo(
                                widget.device, musicInfo);
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
              onPressed: () async {
                Map<String, String> currentMusicInfo =
                    await BLEUtils.getMusicInfo();
                String formattedMusicInfo =
                    "${currentMusicInfo['title']} - ${currentMusicInfo['artist']}";
                await BLEUtils.sendMusicInfo(widget.device, formattedMusicInfo);
              },
              child: const Text('Send Music Info'),
            ),
          ],
        ),
      ),
    );
  }
}
