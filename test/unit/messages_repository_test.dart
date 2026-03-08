import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/api/endpoints.dart';
import 'package:kadmat/src/features/messages/data/messages_repository.dart';
import 'package:kadmat/src/features/messages/domain/conversation_thread.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StubDio extends Fake implements Dio {
  Future<Response<dynamic>> Function(String path)? onGet;
  Future<Response<dynamic>> Function(String path, {dynamic data})? onPost;
  Future<Response<dynamic>> Function(String path)? onPatch;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onGet!(path);
    return response as Response<T>;
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onPost!(path, data: data);
    return response as Response<T>;
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await onPatch!(path);
    return response as Response<T>;
  }
}

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('MessagesRepository', () {
    late StubDio dio;
    late MockSupabaseClient supabaseClient;
    late MessagesRepository repository;

    setUp(() {
      dio = StubDio();
      supabaseClient = MockSupabaseClient();
      repository = MessagesRepository(dio, supabaseClient);
    });

    test('getMessages fetches messages from backend API', () async {
      const jobId = 'job-123';
      final responseData = [
        {
          'id': 'msg-1',
          'job_id': jobId,
          'sender_id': 'sender-1',
          'receiver_id': 'receiver-1',
          'content': 'مرحبا',
          'is_read': false,
          'created_at': DateTime(2026, 3, 7, 10).toIso8601String(),
          'sender': {'id': 'sender-1', 'full_name': 'مرسل'},
        },
      ];

      dio.onGet = (path) async {
        expect(path, Endpoints.messagesForJob(jobId));
        return Response(
          data: {'success': true, 'data': responseData},
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
        );
      };

      final messages = await repository.getMessages(jobId);

      expect(messages, hasLength(1));
      expect(messages.first.content, 'مرحبا');
    });

    test(
      'getMessages maps COMMUNICATION_NOT_AVAILABLE to a user-facing message',
      () async {
        const jobId = 'job-locked';

        dio.onGet = (path) async {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              data: {
                'success': false,
                'error': {
                  'code': 'COMMUNICATION_NOT_AVAILABLE',
                  'message': 'Communication is restricted',
                },
              },
              requestOptions: RequestOptions(path: path),
              statusCode: 403,
            ),
            type: DioExceptionType.badResponse,
          );
        };

        await expectLater(
          () => repository.getMessages(jobId),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('يتاح التواصل فقط بعد قبول العرض'),
            ),
          ),
        );
      },
    );

    test('sendMessage posts only content to backend API', () async {
      const jobId = 'job-123';
      final now = DateTime(2026, 3, 7, 10).toIso8601String();

      dio.onPost = (path, {data}) async {
        expect(path, Endpoints.messagesForJob(jobId));
        expect(data, {'content': 'أهلاً'});
        return Response(
          data: {
            'success': true,
            'data': {
              'id': 'msg-1',
              'job_id': jobId,
              'sender_id': 'customer-1',
              'receiver_id': 'tech-1',
              'content': 'أهلاً',
              'is_read': false,
              'created_at': now,
              'sender': {'id': 'customer-1', 'full_name': 'عميل'},
            },
          },
          requestOptions: RequestOptions(path: path),
          statusCode: 201,
        );
      };

      final message = await repository.sendMessage(
        jobId: jobId,
        content: 'أهلاً',
      );

      expect(message.jobId, jobId);
      expect(message.content, 'أهلاً');
    });

    test('markAsRead reads updated count from backend payload', () async {
      const jobId = 'job-123';
      dio.onPatch = (path) async {
        expect(path, Endpoints.markMessagesRead(jobId));
        return Response(
          data: {
            'success': true,
            'data': {'updated_count': 4},
          },
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
        );
      };

      final updatedCount = await repository.markAsRead(jobId);

      expect(updatedCount, 4);
    });

    test(
      'getConversationThreads returns last message and unread count',
      () async {
        dio.onGet = (path) async {
          expect(path, Endpoints.messageConversations);
          return Response(
            data: {
              'success': true,
              'data': [
                {
                  'job_id': 'job-1',
                  'status': 'on_the_way',
                  'service_name': 'سباكة',
                  'unread_count': 2,
                  'last_message': 'أنا في الطريق',
                  'last_message_at': DateTime(2026, 3, 7, 12).toIso8601String(),
                  'other_user': {
                    'id': 'tech-1',
                    'full_name': 'فني',
                    'profile_image_url': 'tech.png',
                    'phone': '2222222222',
                  },
                },
              ],
            },
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
          );
        };

        final threads = await repository.getConversationThreads();

        expect(threads, hasLength(1));
        expect(threads.first, isA<ConversationThread>());
        expect(threads.first.lastMessage, 'أنا في الطريق');
        expect(threads.first.unreadCount, 2);
      },
    );
  });
}
