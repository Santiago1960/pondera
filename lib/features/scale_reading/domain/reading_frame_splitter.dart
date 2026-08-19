class ReadingFrameSplitResult {
  const ReadingFrameSplitResult({
    required this.completeFrames,
    required this.remainder,
    this.shouldFlushRemainderAfterQuietPeriod = false,
  });

  final List<String> completeFrames;
  final String remainder;
  final bool shouldFlushRemainderAfterQuietPeriod;
}

class ReadingFrameSplitter {
  const ReadingFrameSplitter._();

  static ReadingFrameSplitResult splitComplete(String data) {
    final completeFrames = <String>[];
    var frameStart = 0;
    var index = 0;

    while (index < data.length) {
      if (!_isLineSeparator(data.codeUnitAt(index))) {
        index++;
        continue;
      }

      final separator = data.codeUnitAt(index);
      var frameEnd = index + 1;
      if (separator == 13 &&
          frameEnd < data.length &&
          data.codeUnitAt(frameEnd) == 10) {
        frameEnd++;
      }

      final frame = data.substring(frameStart, frameEnd);
      if (frame.trim().isNotEmpty) {
        completeFrames.add(frame);
      }
      frameStart = frameEnd;
      while (frameStart < data.length &&
          _isLineSeparator(data.codeUnitAt(frameStart))) {
        frameStart++;
      }
      index = frameStart;
    }

    return ReadingFrameSplitResult(
      completeFrames: completeFrames,
      remainder: data.substring(frameStart),
    );
  }

  static bool _isLineSeparator(int codeUnit) =>
      codeUnit == 10 || codeUnit == 13;
}

class ReadingFrameAssembler {
  bool _lineTerminatorsDetected = false;

  ReadingFrameSplitResult assemble(String data) {
    final split = ReadingFrameSplitter.splitComplete(data);
    if (split.completeFrames.isNotEmpty) {
      _lineTerminatorsDetected = true;
    }

    return ReadingFrameSplitResult(
      completeFrames: split.completeFrames,
      remainder: split.remainder,
      shouldFlushRemainderAfterQuietPeriod:
          split.remainder.isNotEmpty && !_lineTerminatorsDetected,
    );
  }

  void reset() {
    _lineTerminatorsDetected = false;
  }
}
