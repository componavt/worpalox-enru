import 'package:flutter/material.dart';

/// Segmented progress bar for the current block: one segment per phrase,
/// filled as phrases are solved. Gives the session a visible finish line.
class BlockProgress extends StatelessWidget {
  const BlockProgress({
    super.key,
    required this.solved,
    required this.total,
  });

  final int solved;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < solved ? Colors.green[400] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
