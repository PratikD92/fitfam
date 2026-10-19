import 'package:flutter/material.dart';
import '../core/config.dart';

/// (i) popup: one-line meaning + formula. Text comes from config.json "info".
void showInfoDialog(BuildContext context, String key) {
  final info = AppConfig.instance.info(key);
  showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(info.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.meaning),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(info.formula,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Got it'))
      ],
    ),
  );
}
