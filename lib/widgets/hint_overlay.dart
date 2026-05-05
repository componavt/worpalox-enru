import 'package:flutter/material.dart';

class HintOverlay extends StatelessWidget {
  final List<bool> hints;
  final List<String> words;

  const HintOverlay({super.key, required this.hints, required this.words});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < hints.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hints[i] ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hints[i] ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: hints[i] ? Colors.green[700] : Colors.red[700],
                ),
                const SizedBox(width: 4),
                Text(
                  words[i],
                  style: TextStyle(
                    fontSize: 14,
                    color: hints[i] ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
