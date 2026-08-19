import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/reading_parser.dart';
import 'package:pondera/features/scale_reading/domain/serial_frame_decoder.dart';

void main() {
  test('aplica la receta solo a tramas GI410 completas', () {
    final decoder = SerialFrameDecoder(maxFrameBytes: 128);

    final initialTail = decoder.add([...'T 0,000C0'.codeUnits, 0x03, 13, 10]);
    expect(initialTail.frames, isEmpty);

    expect(decoder.add([0x02, ...'  N 0,358T '.codeUnits]).frames, isEmpty);
    final completed = decoder.add([
      ...'0,000C0'.codeUnits,
      0x03,
      13,
      10,
      0x02,
      ...'  N 0,358T 0,000C0'.codeUnits,
      0x03,
    ]);
    final completeFrames = completed.frames;

    expect(completed.ignoredBytes, 0);
    expect(completeFrames, ['  N 0,358T 0,000C0', '  N 0,358T 0,000C0']);
    expect(
      completeFrames
          .map(
            (frame) => ReadingParser.parse(
              frame,
              pattern: r'([0-9]+[,.][0-9]+)',
              expectedValue: '0.358',
            )?.numericValue,
          )
          .toList(),
      [0.358, 0.358],
    );

    final zeroFrame = decoder
        .add([0x02, ...'  N 0,000T 0,000C0'.codeUnits, 0x03])
        .frames
        .single;
    expect(
      ReadingParser.parse(
        zeroFrame,
        pattern: r'([0-9]+[,.][0-9]+)',
        expectedValue: '0.358',
      )?.numericValue,
      0,
    );
  });

  test('descarta tramas con bytes de control inválidos', () {
    final decoder = SerialFrameDecoder(maxFrameBytes: 128);

    final result = decoder.add([
      0x02,
      ...'  N 0,358'.codeUnits,
      0x00,
      ...'T 0,000C0'.codeUnits,
      0x03,
    ]);

    expect(result.frames, isEmpty);
  });

  test('conserva indicadores delimitados por línea o pausa', () {
    final decoder = SerialFrameDecoder(maxFrameBytes: 128);

    expect(decoder.add('WT 1.23\r\nWT 2.34\n'.codeUnits).frames, [
      'WT 1.23',
      'WT 2.34',
    ]);
    decoder.add('WT 3.45'.codeUnits);
    expect(decoder.flushPendingUnframedData(), 'WT 3.45');
  });
}
