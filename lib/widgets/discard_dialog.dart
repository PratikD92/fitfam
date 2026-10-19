import 'package:flutter/material.dart';

/// Returns true if the user chose "Yes" (discard).
Future<bool> showDiscardDialog(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('Your unsaved changes will be lost.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('No')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
      ],
    ),
  );
  return r ?? false;
}
