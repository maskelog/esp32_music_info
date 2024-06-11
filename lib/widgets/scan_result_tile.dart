import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({super.key, required this.result, required this.onTap});

  final ScanResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
          result.device.name.isEmpty ? "Unknown Device" : result.device.name),
      subtitle: Text(result.device.id.toString()),
      trailing: ElevatedButton(
        onPressed: onTap,
        child: const Text("CONNECT"),
      ),
    );
  }
}
