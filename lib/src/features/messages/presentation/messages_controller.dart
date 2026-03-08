import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/messages_repository.dart';
import '../domain/message.dart';

part 'messages_controller.g.dart';

@riverpod
class MessagesController extends _$MessagesController {
  @override
  FutureOr<void> build() {
    // no state needed for now
  }

  Future<void> sendMessage({
    required String jobId,
    required String content,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(messagesRepositoryProvider)
          .sendMessage(jobId: jobId, content: content),
    );
  }
}

@riverpod
Stream<List<Message>> messagesStream(Ref ref, String jobId) {
  return ref.watch(messagesRepositoryProvider).watchMessages(jobId);
}
