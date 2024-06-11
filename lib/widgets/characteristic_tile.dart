import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'descriptor_tile.dart';

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;
  final VoidCallback? onNotificationPressed;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile({
    super.key,
    required this.characteristic,
    this.onReadPressed,
    this.onWritePressed,
    this.onNotificationPressed,
    required this.descriptorTiles,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: ListTile(
        title: const Text('Characteristic'),
        subtitle: Text(characteristic.uuid.toString()),
      ),
      children: <Widget>[
        TextButton(
          onPressed: onReadPressed,
          child: const Text('Read'),
        ),
        TextButton(
          onPressed: onWritePressed,
          child: const Text('Write'),
        ),
        TextButton(
          onPressed: onNotificationPressed,
          child: const Text('Notify'),
        ),
        ...descriptorTiles,
      ],
    );
  }
}
