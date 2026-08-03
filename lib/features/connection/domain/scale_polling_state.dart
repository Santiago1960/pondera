class ScalePollingState {
  ScalePollingState({required this.responseTimeout});

  final Duration responseTimeout;

  DateTime? _requestStartedAt;

  bool get waitingForResponse => _requestStartedAt != null;

  bool beginRequest(DateTime requestedAt) {
    if (waitingForResponse) {
      return false;
    }
    _requestStartedAt = requestedAt;
    return true;
  }

  bool hasTimedOut(DateTime now) {
    final requestStartedAt = _requestStartedAt;
    return requestStartedAt != null &&
        now.difference(requestStartedAt) >= responseTimeout;
  }

  void completeResponse() {
    _requestStartedAt = null;
  }

  void reset() {
    _requestStartedAt = null;
  }
}
