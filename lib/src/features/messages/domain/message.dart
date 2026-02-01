// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Message model for chat system
/// Represents a single message between customer and technician
@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'receiver_id') required String receiverId,
    required String content,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'read_at') DateTime? readAt,
    // Sender information (joined from users table)
    MessageSender? sender,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

/// Sender information for messages
@freezed
class MessageSender with _$MessageSender {
  const factory MessageSender({
    required String id,
    @JsonKey(name: 'full_name') String? fullName,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _MessageSender;

  factory MessageSender.fromJson(Map<String, dynamic> json) =>
      _$MessageSenderFromJson(json);
}

/// Conversation model for chat list
@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    @JsonKey(name: 'job_id') required String jobId,
    required String status,
    @JsonKey(name: 'service_name') String? serviceName,
    @JsonKey(name: 'other_user') ConversationUser? otherUser,
    @JsonKey(name: 'unread_count') @Default(0) int unreadCount,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

/// User info in conversation
@freezed
class ConversationUser with _$ConversationUser {
  const factory ConversationUser({
    required String id,
    @JsonKey(name: 'full_name') String? fullName,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _ConversationUser;

  factory ConversationUser.fromJson(Map<String, dynamic> json) =>
      _$ConversationUserFromJson(json);
}

/// Unread count by job
@freezed
class UnreadCountByJob with _$UnreadCountByJob {
  const factory UnreadCountByJob({
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'unread_count') @Default(0) int unreadCount,
  }) = _UnreadCountByJob;

  factory UnreadCountByJob.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountByJobFromJson(json);
}
