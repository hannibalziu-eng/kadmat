import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/messages/data/messages_repository.dart';

import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  SupabaseQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  RealtimeChannel,
])
import 'messages_repository_test.mocks.dart';

void main() {
  group('MessagesRepository Tests', () {
    late MessagesRepository repository;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuth;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();

      // Setup Auth
      when(mockSupabaseClient.auth).thenReturn(mockAuth);

      repository = MessagesRepository(mockSupabaseClient);
    });

    test('markAsRead calls RPC correctly', () async {
      // Arrange
      const jobId = 'job-123';
      const userId = 'user-123';

      when(mockAuth.currentUser).thenReturn(
        User(
          id: userId,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
        ),
      );

      when(
        mockSupabaseClient.rpc(
          'mark_messages_as_read',
          params: {'p_job_id': jobId, 'p_user_id': userId},
        ),
      ).thenAnswer((_) => FakePostgrestBuilder(5) as dynamic);

      // Act
      final result = await repository.markAsRead(jobId);

      // Assert
      expect(result, 5);
      verify(
        mockSupabaseClient.rpc(
          'mark_messages_as_read',
          params: {'p_job_id': jobId, 'p_user_id': userId},
        ),
      ).called(1);
    });

    test('sendMessage returns Message on success', () async {
      // Arrange
      const jobId = 'job-123';
      const userId = 'sender-123';
      const receiverId = 'receiver-123';
      const content = 'Hello';

      final Map<String, dynamic> mockResponse = {
        'id': 'msg-1',
        'job_id': jobId,
        'sender_id': userId,
        'receiver_id': receiverId,
        'content': content,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'sender': {
          'id': userId,
          'full_name': 'Test User',
          'profile_image_url': null,
        },
      };

      when(mockAuth.currentUser).thenReturn(
        User(
          id: userId,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
        ),
      );

      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder =
          MockPostgrestFilterBuilder<List<Map<String, dynamic>>>();
      final mockTransformBuilder =
          MockPostgrestTransformBuilder<List<Map<String, dynamic>>>();

      // Mock the chain: client.from() -> insert() -> select() -> single()
      when(
        mockSupabaseClient.from('messages'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        mockQueryBuilder.insert(any),
      ).thenAnswer((_) => mockFilterBuilder as dynamic);
      when(
        mockFilterBuilder.select(any),
      ).thenAnswer((_) => mockTransformBuilder as dynamic);
      when(
        mockTransformBuilder.single(),
      ).thenAnswer((_) => FakePostgrestBuilder(mockResponse) as dynamic);

      // Act
      final result = await repository.sendMessage(
        jobId: jobId,
        content: content,
        receiverId: receiverId,
      );

      // Assert
      expect(result.content, content);
      expect(result.senderId, userId);

      verify(mockSupabaseClient.from('messages')).called(1);
      verify(
        mockQueryBuilder.insert({
          'job_id': jobId,
          'sender_id': userId,
          'receiver_id': receiverId,
          'content': content,
        }),
      ).called(1);
    });
  });
}

class FakePostgrestBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;
  FakePostgrestBuilder(this._value);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) async {
    return onValue(_value);
  }
}
