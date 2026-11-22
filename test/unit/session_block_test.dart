import 'package:flutter_test/flutter_test.dart';
import 'package:worpalox/services/session_block.dart';

void main() {
  test('five solved phrases complete a block', () {
    final block = SessionBlock();
    expect(block.isBlockComplete, isFalse);
    for (var i = 0; i < SessionBlock.blockSize; i++) {
      block.registerSolved();
    }
    expect(block.solvedInBlock, SessionBlock.blockSize);
    expect(block.isBlockComplete, isTrue);
  });

  test('counter does not overflow past the block size', () {
    final block = SessionBlock();
    for (var i = 0; i < SessionBlock.blockSize + 2; i++) {
      block.registerSolved();
    }
    expect(block.solvedInBlock, SessionBlock.blockSize);
    expect(block.isBlockComplete, isTrue);
  });

  test('startNextBlock resets the counter', () {
    final block = SessionBlock()
      ..registerSolved()
      ..registerSolved();
    block.startNextBlock();
    expect(block.solvedInBlock, 0);
    expect(block.isBlockComplete, isFalse);
  });

  test('notifies listeners on register and reset', () {
    var notifications = 0;
    final block = SessionBlock()..addListener(() => notifications++);
    block.registerSolved();
    block.startNextBlock();
    expect(notifications, 2);
  });
}
