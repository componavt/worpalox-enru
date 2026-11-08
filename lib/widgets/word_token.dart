import 'package:flutter/material.dart';

/// Visual state of a word chip in the puzzle.
enum WordTokenState { normal, selected, hintCorrect, hintWrong, solved }

/// Which side of the chip shows the "drop here" marker while dragging.
enum DropSide { none, before, after }

class WordToken extends StatelessWidget {
  final String word;
  final WordTokenState state;
  final DropSide dropSide;
  final bool faded;

  const WordToken({
    super.key,
    required this.word,
    this.state = WordTokenState.normal,
    this.dropSide = DropSide.none,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color background = Colors.white;
    Color border = Colors.grey[300]!;
    Color text = Colors.black87;

    switch (state) {
      case WordTokenState.normal:
        break;
      case WordTokenState.selected:
        background = scheme.primaryContainer;
        border = scheme.primary;
        text = scheme.onPrimaryContainer;
      case WordTokenState.hintCorrect:
      case WordTokenState.solved:
        background = Colors.green[100]!;
        border = Colors.green[400]!;
        text = Colors.green[900]!;
      case WordTokenState.hintWrong:
        background = Colors.red[50]!;
        border = Colors.red[300]!;
        text = Colors.red[900]!;
    }

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 2),
        boxShadow: state == WordTokenState.selected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: Text(
        word,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );

    final marker = Container(
      width: 4,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return Opacity(
      opacity: faded ? 0.3 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dropSide == DropSide.before) marker,
          chip,
          if (dropSide == DropSide.after) marker,
        ],
      ),
    );
  }
}
