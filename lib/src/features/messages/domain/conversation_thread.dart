class ConversationThread {
  const ConversationThread({
    required this.jobId,
    required this.status,
    required this.unreadCount,
    this.serviceName,
    this.otherUser,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String jobId;
  final String status;
  final String? serviceName;
  final ConversationThreadUser? otherUser;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  factory ConversationThread.fromJson(Map<String, dynamic> json) {
    return ConversationThread(
      jobId: json['job_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      serviceName: json['service_name']?.toString(),
      otherUser: json['other_user'] is Map<String, dynamic>
          ? ConversationThreadUser.fromJson(
              json['other_user'] as Map<String, dynamic>,
            )
          : json['other_user'] is Map
          ? ConversationThreadUser.fromJson(
              Map<String, dynamic>.from(json['other_user'] as Map),
            )
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.tryParse(json['last_message_at'].toString()),
    );
  }
}

class ConversationThreadUser {
  const ConversationThreadUser({
    required this.id,
    this.fullName,
    this.profileImageUrl,
    this.phone,
  });

  final String id;
  final String? fullName;
  final String? profileImageUrl;
  final String? phone;

  factory ConversationThreadUser.fromJson(Map<String, dynamic> json) {
    return ConversationThreadUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}
