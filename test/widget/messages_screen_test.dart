import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/messages/data/messages_repository.dart';
import 'package:kadmat/src/features/messages/domain/conversation_thread.dart';
import 'package:kadmat/src/features/messages/presentation/messages_screen.dart';

void main() {
  testWidgets(
    'MessagesScreen shows an empty state when there are no conversations',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationThreadsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: MessagesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا توجد محادثات متاحة الآن'), findsOneWidget);
    },
  );

  testWidgets(
    'MessagesScreen renders real conversation data instead of mock cards',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationThreadsProvider.overrideWith(
              (ref) async => const [
                ConversationThread(
                  jobId: 'job-1',
                  status: 'on_the_way',
                  serviceName: 'سباكة',
                  unreadCount: 2,
                  lastMessage: 'أنا في الطريق',
                  otherUser: ConversationThreadUser(
                    id: 'tech-1',
                    fullName: 'فني حقيقي',
                    phone: '2222222222',
                  ),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: MessagesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('فني حقيقي'), findsOneWidget);
      expect(find.text('أنا في الطريق'), findsOneWidget);
      expect(find.text('سارة أحمد'), findsNothing);
    },
  );
}
