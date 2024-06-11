import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(const FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  const FlutterBlueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothAdapterState>(
        stream: FlutterBluePlus.adapterState,
        initialData: BluetoothAdapterState.unknown,
        builder: (c, snapshot) {
          final state = snapshot.data!;
          if (state == BluetoothAdapterState.on) {
            return const ScanScreen();
          }
          return BluetoothOffScreen(adapterState: state);
        },
      ),
    );
  }
}
