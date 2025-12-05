import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'الرسائل',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.search), onPressed: () {}),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children:
            [
                  _buildMessageCard(
                    context,
                    name: 'سارة أحمد',
                    time: '10:45 ص',
                    lastMessage: 'بالتأكيد، يمكنني البدء في العمل غدًا صباحًا.',
                    orderStatus: 'طلب: إصلاح تسريب حوض المطبخ',
                    orderStatusColor: const Color(0xFF13b6ec),
                    avatarUrl: 'https://i.pravatar.cc/150?img=5',
                    showCallAndView: true,
                  ),
                  SizedBox(height: 16.h),
                  _buildMessageCard(
                    context,
                    name: 'يوسف علي',
                    time: 'أمس',
                    lastMessage: 'تم إرسال عرض السعر، في انتظار موافقتك.',
                    orderStatus: 'طلب: تركيب إضاءة جديدة للغرفة',
                    orderStatusColor: const Color(0xFF13b6ec),
                    avatarUrl: 'https://i.pravatar.cc/150?img=12',
                    showCallAndView: true,
                  ),
                  SizedBox(height: 16.h),
                  _buildMessageCard(
                    context,
                    name: 'فاطمة عمر',
                    time: '2 يوم',
                    lastMessage: 'شكرًا لك، لقد أتممت المهمة بنجاح!',
                    orderStatus: 'طلب مكتمل: تصليح باب خشبي',
                    orderStatusColor: Colors.green,
                    avatarUrl: 'https://i.pravatar.cc/150?img=20',
                    showCallAndView: false,
                    showRating: true,
                  ),
                  SizedBox(height: 80.h), // Bottom nav padding
                ]
                .animate(interval: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideX(begin: 0.2, end: 0),
      ),
    );
  }

  Widget _buildMessageCard(
    BuildContext context, {
    required String name,
    required String time,
    required String lastMessage,
    required String orderStatus,
    required Color orderStatusColor,
    required String avatarUrl,
    bool showCallAndView = true,
    bool showRating = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28.r,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16.fz,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12.fz,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        lastMessage,
                        style: TextStyle(
                          fontSize: 14.fz,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        orderStatus,
                        style: TextStyle(
                          fontSize: 12.fz,
                          color: orderStatusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showCallAndView) ...[
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.call, size: 18.s),
                    label: Text('اتصال', style: TextStyle(fontSize: 13.fz)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.visibility, size: 18.s),
                    label: Text('عرض الطلب', style: TextStyle(fontSize: 13.fz)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13b6ec),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                  ),
                ],
                if (showRating)
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.star, size: 18.s),
                    label: Text(
                      'تقييم الخدمة',
                      style: TextStyle(fontSize: 13.fz),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
