abstract class PushGateway {
  Future<void> initialize();
  Stream<String> get onTokenRefresh;
  Stream<String> get navigationStream;
  String? get currentToken;

  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}

/// Development/web fallback gateway that keeps the app flow functional
/// without requiring Firebase services.
class NoopPushGateway implements PushGateway {
  @override
  Future<void> initialize() async {
    // No-op by design.
  }

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Stream<String> get navigationStream => const Stream<String>.empty();

  @override
  String? get currentToken => null;

  @override
  Future<void> subscribeToTopic(String topic) async {
    // No-op by design.
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    // No-op by design.
  }
}
