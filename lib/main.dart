import 'package:flutter/material.dart';
import 'package:music_info/screens/scan_screen.dart';
import 'package:music_info/services/background_service.dart';

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

  void _navigateToScanScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
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
          ],
        ),
      ),
    );
  }
}
