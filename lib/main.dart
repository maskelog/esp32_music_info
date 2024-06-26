import 'package:flutter/material.dart';
import 'package:music_info/screens/scan_screen.dart';
import 'package:music_info/screens/device_screen.dart';
import 'package:music_info/services/background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  bool _isServiceRunning = false;
  BluetoothDevice? _connectedDevice;

  void _navigateToScanScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanScreen(
          onDeviceConnected: (device) {
            setState(() {
              _connectedDevice = device;
            });
          },
        ),
      ),
    );
  }

  void _navigateToDeviceScreen() {
    if (_connectedDevice != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceScreen(device: _connectedDevice!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No device selected")),
      );
    }
  }

  void _toggleService() {
    if (_isServiceRunning) {
      stopBackgroundService();
    } else {
      startBackgroundService();
    }
    setState(() {
      _isServiceRunning = !_isServiceRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter BLE Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('BLE Connect'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToScanScreen,
              child: const Text('장치 검색'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleService,
              child: Text(_isServiceRunning ? '서비스 중지' : '서비스 시작'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToDeviceScreen,
              child: const Text('연결된 장치'),
            ),
          ],
        ),
      ),
    );
  }
}
