import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/message.dart';

/// Chat bubble widget for displaying a single message
class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showTime;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for other user
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.sender?.profileImageUrl != null
                  ? NetworkImage(message.sender!.profileImageUrl!)
                  : null,
              child: message.sender?.profileImageUrl == null
                  ? Text(
                      (message.sender?.fullName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? theme.colorScheme.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Message content
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Time and read status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Spacing for alignment
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(dateTime); // 14:30
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'أمس ${DateFormat.Hm().format(dateTime)}';
    } else {
      return DateFormat('MM/dd HH:mm').format(dateTime);
    }
  }
}
