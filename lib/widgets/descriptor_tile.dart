import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;

  const DescriptorTile({
    super.key,
    required this.descriptor,
    this.onReadPressed,
    this.onWritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: ListTile(
        title: const Text('Descriptor'),
        subtitle: Text(descriptor.uuid.toString()),
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
      ],
    );
  }
}
