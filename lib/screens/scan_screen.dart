import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:music_info/screens/device_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:music_info/utils/utils.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  String _scanStatus = "Idle";
  String _errorMessage = "";
  BluetoothDevice? _connectedDevice;
  String _musicInfo = "None";

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _loadLastConnectedDevice();
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
        _musicInfo = await BLEUtils.getMusicInfo();
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                DeviceScreen(device: device, musicInfo: _musicInfo),
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
