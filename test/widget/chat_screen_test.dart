import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/messages/domain/message.dart';
import 'package:kadmat/src/features/messages/presentation/chat_controller.dart';
import 'package:kadmat/src/features/messages/presentation/chat_screen.dart';

class BlockedChatController extends ChatController {
  @override
  AsyncValue<List<Message>> build(String jobId) {
    return AsyncValue.error(
      Exception('يتاح التواصل فقط بعد قبول العرض'),
      StackTrace.empty,
    );
  }
}

void main() {
  testWidgets(
    'ChatScreen hides input and retry button when communication is blocked',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatControllerProvider(
              'job-1',
            ).overrideWith(() => BlockedChatController()),
          ],
          child: const MaterialApp(
            home: ChatScreen(jobId: 'job-1', otherUserName: 'فني'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('يتاح التواصل فقط بعد قبول العرض'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
