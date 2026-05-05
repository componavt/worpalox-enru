import 'package:flutter/material.dart';

class WordToken extends StatelessWidget {
  final String word;
  final bool? isCorrect;
  final bool isSolved;

  const WordToken({
    super.key,
    required this.word,
    this.isCorrect,
    this.isSolved = false,
  });

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;
    Color? textColor;

    if (isSolved) {
      backgroundColor = Colors.green[100];
      textColor = Colors.green[800];
    } else if (isCorrect == true) {
      backgroundColor = Colors.green[100];
      textColor = Colors.green[800];
    } else if (isCorrect == false) {
      backgroundColor = Colors.red[100];
      textColor = Colors.red[800];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect == true
              ? Colors.green[400]!
              : isCorrect == false
                  ? Colors.red[400]!
                  : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Text(
        word,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.black87,
        ),
      ),
    );
  }
}
