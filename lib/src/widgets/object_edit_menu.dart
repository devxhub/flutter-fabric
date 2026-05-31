import 'package:flutter/material.dart';
import '../canvas/fabric_controller.dart';
import '../objects/fabric_object.dart';

/// A bottom sheet that shows editing options for an object.
class ObjectEditMenu extends StatelessWidget {
  const ObjectEditMenu({
    super.key,
    required this.controller,
    required this.object,
    required this.onDelete,
    required this.onDuplicate,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onLockMovement,
    required this.onUnlockMovement,
    required this.onToggleVisible,
  });

  final FabricController controller;
  final FabricObject object;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final VoidCallback onLockMovement;
  final VoidCallback onUnlockMovement;
  final VoidCallback onToggleVisible;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Duplicate'),
            onTap: onDuplicate,
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: onDelete,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.vertical_align_top),
            title: const Text('Bring to Front'),
            onTap: onBringToFront,
          ),
          ListTile(
            leading: const Icon(Icons.vertical_align_bottom),
            title: const Text('Send to Back'),
            onTap: onSendToBack,
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('Bring Forward'),
            onTap: onBringForward,
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward),
            title: const Text('Send Backward'),
            onTap: onSendBackward,
          ),
          const Divider(),
          if (object.lockMovementX && object.lockMovementY)
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('Unlock Movement'),
              onTap: onUnlockMovement,
            )
          else
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Lock Movement'),
              onTap: onLockMovement,
            ),
          ListTile(
            leading:
                Icon(object.visible ? Icons.visibility : Icons.visibility_off),
            title: Text(object.visible ? 'Hide' : 'Show'),
            onTap: onToggleVisible,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
