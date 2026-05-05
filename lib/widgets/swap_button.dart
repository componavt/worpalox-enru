import 'package:flutter/material.dart';

class SwapButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const SwapButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.swap_horiz),
      iconSize: 24,
      tooltip: 'Swap adjacent words',
      color: enabled ? Colors.deepPurple : Colors.grey[400],
    );
  }
}
