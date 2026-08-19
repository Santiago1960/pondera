import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/reading_frame_splitter.dart';

void main() {
  test('conserva una trama incompleta hasta recibir el terminador', () {
    final firstChunk = ReadingFrameSplitter.splitComplete('ST,+000');

    expect(firstChunk.completeFrames, isEmpty);
    expect(firstChunk.remainder, 'ST,+000');

    final secondChunk = ReadingFrameSplitter.splitComplete(
      '${firstChunk.remainder}0.42kg\r\n',
    );

    expect(secondChunk.completeFrames, ['ST,+0000.42kg\r\n']);
    expect(secondChunk.remainder, isEmpty);
  });

  test('separa varias tramas y conserva el fragmento final', () {
    final result = ReadingFrameSplitter.splitComplete(
      'WT 0.00 kg\r\nWT 0.42 kg\nWT 0.',
    );

    expect(result.completeFrames, ['WT 0.00 kg\r\n', 'WT 0.42 kg\n']);
    expect(result.remainder, 'WT 0.');
  });

  test('ignora separadores vacíos entre tramas', () {
    final result = ReadingFrameSplitter.splitComplete('\r\nWT 0.42 kg\r\n\r\n');

    expect(result.completeFrames, ['WT 0.42 kg\r\n']);
    expect(result.remainder, isEmpty);
  });

  test(
    'no libera por silencio un fragmento cuando ya detectó tramas CR/LF',
    () {
      final assembler = ReadingFrameAssembler();

      final zeroFrame = assembler.assemble('N 0,000T 0,000C0\r\n');
      expect(zeroFrame.completeFrames, ['N 0,000T 0,000C0\r\n']);
      expect(zeroFrame.shouldFlushRemainderAfterQuietPeriod, isFalse);

      final partialWeight = assembler.assemble('N 0,3');
      expect(partialWeight.completeFrames, isEmpty);
      expect(partialWeight.remainder, 'N 0,3');
      expect(partialWeight.shouldFlushRemainderAfterQuietPeriod, isFalse);

      final completedWeight = assembler.assemble(
        '${partialWeight.remainder}70T 0,000C0\r\n',
      );
      expect(completedWeight.completeFrames, ['N 0,370T 0,000C0\r\n']);
      expect(completedWeight.remainder, isEmpty);
    },
  );

  test('mantiene el fallback para equipos que no envían terminadores', () {
    final assembler = ReadingFrameAssembler();

    final result = assembler.assemble('N 0,370T 0,000C0');

    expect(result.completeFrames, isEmpty);
    expect(result.remainder, 'N 0,370T 0,000C0');
    expect(result.shouldFlushRemainderAfterQuietPeriod, isTrue);
  });
}
