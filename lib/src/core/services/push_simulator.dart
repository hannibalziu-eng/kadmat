import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_simulator.g.dart';

class PushSimulator {
  final List<String> _subscribedTopics = [];
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  void subscribeToTopic(String topic) {
    if (!_subscribedTopics.contains(topic)) {
      _subscribedTopics.add(topic);
      print('Subscribed to topic: $topic');
    }
  }

  void unsubscribeFromTopic(String topic) {
    _subscribedTopics.remove(topic);
    print('Unsubscribed from topic: $topic');
  }

  // Simulate receiving a push notification
  void simulatePush({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final message = {
      'notification': {'title': title, 'body': body},
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    _messageController.add(message);
  }

  void dispose() {
    _messageController.close();
  }
}

@riverpod
PushSimulator pushSimulator(PushSimulatorRef ref) {
  final simulator = PushSimulator();
  ref.onDispose(() => simulator.dispose());
  return simulator;
}
