import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:music_info/utils/utils.dart';
import 'package:music_info/screens/device_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

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
    _getMusicInfo();
    _loadAvailablePlayers();
  }

  Future<void> _loadAvailablePlayers() async {
    try {
      List<String> players = await BLEUtils.getAvailablePlayers();
      setState(() {
        _availablePlayers = players;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error retrieving available players: $e";
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
        _musicInfo = "Error retrieving music info: $e";
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
          _errorMessage = "Permissions not granted";
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
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DeviceScreen(device: device),
          ));
        }
      } catch (e) {
        retryCount++;
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to connect: $e (attempt $retryCount)';
          });
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _selectPlayer(String player) async {
    try {
      await BLEUtils.selectPlayer(player);
      setState(() {
        _selectedPlayer = player;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error selecting player: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan for Devices')),
      body: Column(
        children: <Widget>[
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: $_errorMessage',
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
                hint: const Text('Select Music Player'),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    _selectPlayer(newValue);
                  }
                },
                items: _availablePlayers
                    .map<DropdownMenuItem<String>>((String player) {
                  return DropdownMenuItem<String>(
                    value: player,
                    child: Text(player),
                  );
                }).toList(),
              ),
            ),
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
