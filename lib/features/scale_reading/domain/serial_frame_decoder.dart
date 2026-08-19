class SerialFrameDecoder {
  SerialFrameDecoder({required this.maxFrameBytes});

  static const _stx = 0x02;
  static const _etx = 0x03;

  final int maxFrameBytes;
  final List<int> _buffer = [];
  bool _usesControlFrames = false;
  bool _insideControlFrame = false;
  bool _damaged = false;

  bool get hasPendingUnframedData => !_usesControlFrames && _buffer.isNotEmpty;

  ({List<String> frames, int ignoredBytes}) add(List<int> bytes) {
    final frames = <String>[];
    var ignoredBytes = 0;

    for (final byte in bytes) {
      if (byte == _stx) {
        ignoredBytes += _buffer.length;
        _buffer.clear();
        _usesControlFrames = true;
        _insideControlFrame = true;
        _damaged = false;
        continue;
      }

      if (byte == _etx) {
        _usesControlFrames = true;
        if (_insideControlFrame) {
          _completeFrame(frames);
        } else {
          ignoredBytes += _buffer.length + 1;
          _buffer.clear();
        }
        _insideControlFrame = false;
        _damaged = false;
        continue;
      }

      if (_usesControlFrames && !_insideControlFrame) {
        if (byte != 10 && byte != 13) {
          ignoredBytes++;
        }
        continue;
      }

      if (!_usesControlFrames && (byte == 10 || byte == 13)) {
        if (_buffer.isNotEmpty) {
          _completeFrame(frames);
        }
        _damaged = false;
        continue;
      }

      final isAllowedTextByte =
          byte == 9 || byte == 10 || byte == 13 || byte >= 32;
      if (!isAllowedTextByte || _buffer.length >= maxFrameBytes) {
        _damaged = true;
        ignoredBytes++;
        continue;
      }
      _buffer.add(byte);
    }

    return (frames: frames, ignoredBytes: ignoredBytes);
  }

  String? flushPendingUnframedData() {
    if (!hasPendingUnframedData) {
      return null;
    }
    final frame = _damaged ? null : String.fromCharCodes(_buffer);
    _buffer.clear();
    _damaged = false;
    return frame;
  }

  void reset() {
    _buffer.clear();
    _usesControlFrames = false;
    _insideControlFrame = false;
    _damaged = false;
  }

  void _completeFrame(List<String> frames) {
    if (!_damaged && _buffer.isNotEmpty) {
      frames.add(String.fromCharCodes(_buffer));
    }
    _buffer.clear();
  }
}
