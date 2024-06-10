import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static const platform =
      MethodChannel('com.example.ble_music_info/music_info');
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devicesList = [];
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;

  String musicInfo = "Waiting for music...";
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    var statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location, // 위치 권한 추가
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      _showMessage("All permissions granted");
    } else {
      _showMessage("Permissions not granted");
      setState(() {
        errorMessage = "Permissions not granted";
      });
    }
  }

  void startScanning() {
    devicesList.clear();
    setState(() {
      errorMessage = "Starting scan...";
    });
    flutterBlue.startScan(
      timeout: const Duration(seconds: 10),
      // 필터 추가 - 특정 서비스 UUID로 필터링
      withServices: [Guid("3db02924-b2a6-4d47-be1f-0f90ad62a048")],
    ).then((_) {
      setState(() {
        errorMessage = "Scan completed";
      }); // 스캔 완료 후 UI 업데이트
    }).catchError((e) {
      _showMessage("Error starting scan: $e");
      setState(() {
        errorMessage = "Error starting scan: $e";
      });
    });

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        print('Found device: ${r.device.name}, ${r.device.id}');
        if (!devicesList.contains(r.device)) {
          setState(() {
            devicesList.add(r.device);
          });
        }
      }
      if (results.isEmpty) {
        setState(() {
          errorMessage = "No devices found";
        });
      }
    }).onError((error) {
      _showMessage("Error during scan: $error");
      setState(() {
        errorMessage = "Error during scan: $error";
      });
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    targetDevice = device;
    try {
      await targetDevice!.connect(autoConnect: false);
      discoverServices();
    } catch (e) {
      _showMessage("Error connecting to device: $e");
      setState(() {
        errorMessage = "Error connecting to device: $e";
      });
    }
  }

  Future<void> discoverServices() async {
    if (targetDevice == null) return;

    try {
      List<BluetoothService> services = await targetDevice!.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == "3db02924-b2a6-4d47-be1f-0f90ad62a048") {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "8d8218b6-97bc-4527-a8db-13094ac06b1d") {
              setState(() {
                targetCharacteristic = characteristic;
              });
              getMusicInfo();
              return;
            }
          }
        }
      }
    } catch (e) {
      _showMessage("Error discovering services: $e");
      setState(() {
        errorMessage = "Error discovering services: $e";
      });
    }
  }

  Future<void> getMusicInfo() async {
    try {
      final String result = await platform.invokeMethod('getMusicInfo');
      setState(() {
        musicInfo = result;
      });
      sendMusicInfo(result);
    } catch (e) {
      _showMessage("Error getting music info: $e");
      setState(() {
        errorMessage = "Error getting music info: $e";
      });
    }
  }

  Future<void> sendMusicInfo(String musicInfo) async {
    if (targetCharacteristic == null) return;

    try {
      List<int> bytes = utf8.encode(musicInfo);
      await targetCharacteristic!.write(bytes);
    } catch (e) {
      _showMessage("Error sending music info: $e");
      setState(() {
        errorMessage = "Error sending music info: $e";
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Music Info")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: startScanning,
            child: const Text('Scan for Devices'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devicesList[index].name),
                  subtitle: Text(devicesList[index].id.toString()),
                  onTap: () => connectToDevice(devicesList[index]),
                );
              },
            ),
          ),
          Text(musicInfo),
          if (errorMessage.isNotEmpty)
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
