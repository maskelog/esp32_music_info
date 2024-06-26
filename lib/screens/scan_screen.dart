import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:music_info/utils/utils.dart';
import 'package:music_info/screens/device_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanScreen extends StatefulWidget {
  final void Function(BluetoothDevice device) onDeviceConnected;

  const ScanScreen({required this.onDeviceConnected, super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  String _scanStatus = "Idle";
  String _errorMessage = "";
  String _musicInfo = "None";
  String? _selectedPlayer;
  List<String> _availablePlayers = [];
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _loadLastConnectedDevice();
    _loadAvailablePlayers();
    _getMusicInfo();
  }

  Future<void> _loadAvailablePlayers() async {
    try {
      List<String> players = await BLEUtils.getAvailablePlayers();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedPlayer = prefs.getString('selectedPlayer');
      setState(() {
        _availablePlayers = players;
        _selectedPlayer =
            savedPlayer ?? (players.isNotEmpty ? players[0] : null);
      });
    } catch (e) {
      setState(() {
        _errorMessage = "사용 가능한 플레이어를 가져오는 중 오류 발생: $e";
      });
    }
  }

  Future<void> _selectPlayer(String? player) async {
    if (player != null) {
      try {
        await BLEUtils.selectPlayer(player);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('selectedPlayer', player);
        setState(() {
          _selectedPlayer = player;
          _errorMessage = "선택한 플레이어: $player";
        });
      } catch (e) {
        setState(() {
          _errorMessage = "플레이어 선택 중 오류 발생: $e";
        });
      }
    } else {
      setState(() {
        _errorMessage = "음악 플레이어를 선택해주세요";
      });
    }
  }

  Future<void> _getMusicInfo() async {
    try {
      final Map<String, String> result = await BLEUtils.getMusicInfo();
      setState(() {
        _musicInfo = "${result['title']} - ${result['artist']}";
      });
    } catch (e) {
      setState(() {
        _musicInfo = "음악 정보를 가져오는 중 오류 발생: $e";
      });
    }
  }

  Future<void> _loadLastConnectedDevice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('lastConnectedDeviceId');
    if (deviceId != null) {
      List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
      for (BluetoothDevice device in devices) {
        if (device.id.id == deviceId) {
          _connectedDevice = device;
          await connectAndNavigate(device);
          break;
        }
      }
    }
  }

  Future<void> requestPermissions() async {
    var status = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    if (status[Permission.bluetooth]!.isGranted &&
        status[Permission.bluetoothConnect]!.isGranted &&
        status[Permission.bluetoothScan]!.isGranted &&
        status[Permission.location]!.isGranted) {
      startScan();
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = "권한이 허용되지 않았습니다.";
        });
      }
    }
  }

  void startScan() {
    if (mounted) {
      setState(() {
        _scanStatus = "Scanning";
        _errorMessage = "";
      });
    }

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)).then((_) {
      if (mounted) {
        setState(() {
          _scanStatus = "Idle";
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _scanStatus = "Idle";
        });
      }
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    if (mounted) {
      setState(() {
        _scanStatus = "Stopped";
      });
    }
  }

  Future<void> connectAndNavigate(BluetoothDevice device) async {
    int retryCount = 0;
    bool connected = false;
    while (!connected && retryCount < 3) {
      try {
        await device.connect(timeout: const Duration(seconds: 10));
        connected = true;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastConnectedDeviceId', device.id.id);
        _connectedDevice = device;
        widget
            .onDeviceConnected(device); // Update connected device in main.dart
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DeviceScreen(device: device),
          ));
        }
      } catch (e) {
        retryCount++;
        if (mounted) {
          setState(() {
            _errorMessage = '연결 실패: $e (시도 $retryCount)';
          });
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (connected) {
      BLEUtils.monitorMusicInfo(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Devices'),
      ),
      body: Column(
        children: <Widget>[
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '오류: $_errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Scan Status: $_scanStatus'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                Text('Connected Device: ${_connectedDevice?.name ?? 'None'}'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Music Info: $_musicInfo'),
          ),
          if (_availablePlayers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: _selectedPlayer,
                hint: const Text('음악 플레이어 선택'),
                onChanged: (String? newValue) {
                  _selectPlayer(newValue);
                },
                items: _availablePlayers
                    .map<DropdownMenuItem<String>>((String player) {
                  return DropdownMenuItem<String>(
                    value: player,
                    child: Text(player),
                  );
                }).toList(),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (_connectedDevice != null)
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DeviceScreen(device: _connectedDevice!),
              )),
              child: const Text("Go to Connected Device"),
            ),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: FlutterBluePlus.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text("No devices found."));
                }
                return ListView(
                  children: snapshot.data!.map((ScanResult result) {
                    return ListTile(
                      title: Text(result.device.name.isEmpty
                          ? "Unknown Device"
                          : result.device.name),
                      subtitle: Text(result.device.id.toString()),
                      trailing: ElevatedButton(
                        onPressed: () => connectAndNavigate(result.device),
                        child: const Text("CONNECT"),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBluePlus.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              onPressed: stopScan,
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop),
            );
          } else {
            return FloatingActionButton(
              onPressed: startScan,
              child: const Icon(Icons.search),
            );
          }
        },
      ),
    );
  }
}
