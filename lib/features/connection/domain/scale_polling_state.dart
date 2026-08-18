class ScalePollingState {
  ScalePollingState({required this.responseTimeout});

  final Duration responseTimeout;

  DateTime? _requestStartedAt;
  int _consecutiveTimeouts = 0;
  int _consecutiveResponses = 0;

  bool get waitingForResponse => _requestStartedAt != null;
  int get consecutiveTimeouts => _consecutiveTimeouts;
  int get consecutiveResponses => _consecutiveResponses;

  bool beginRequest(DateTime requestedAt, {bool trackResponse = true}) {
    if (!trackResponse) {
      _requestStartedAt = null;
      return true;
    }
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

  void completeTimeout() {
    if (!waitingForResponse) {
      return;
    }
    _requestStartedAt = null;
    _consecutiveTimeouts++;
    _consecutiveResponses = 0;
  }

  void completeResponse() {
    _requestStartedAt = null;
    _consecutiveTimeouts = 0;
    _consecutiveResponses++;
  }

  void reset() {
    _requestStartedAt = null;
    _consecutiveTimeouts = 0;
    _consecutiveResponses = 0;
  }
}
