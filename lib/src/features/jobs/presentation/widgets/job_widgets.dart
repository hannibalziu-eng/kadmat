import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';

/// Job Status Badge - Shows status with icon and Arabic label
class JobStatusBadge extends StatelessWidget {
  final String status;

  const JobStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 16.s),
          SizedBox(width: 6.w),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 12.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return _StatusConfig(
          Icons.hourglass_empty,
          Colors.orange,
          'قيد الانتظار',
        );
      case 'searching':
        return _StatusConfig(Icons.search, Colors.blue, 'جاري البحث');
      case 'accepted':
        return _StatusConfig(Icons.check_circle, Colors.green, 'تم القبول');
      case 'price_pending':
        return _StatusConfig(Icons.attach_money, Colors.amber, 'بانتظار السعر');
      case 'in_progress':
        return _StatusConfig(Icons.engineering, Colors.blue, 'جاري التنفيذ');
      case 'completed':
        return _StatusConfig(Icons.done_all, Colors.teal, 'مكتمل');
      case 'rated':
        return _StatusConfig(Icons.star, Colors.amber, 'تم التقييم');
      case 'cancelled':
        return _StatusConfig(Icons.cancel, Colors.red, 'ملغي');
      default:
        return _StatusConfig(Icons.help, Colors.grey, status);
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final String label;

  _StatusConfig(this.icon, this.color, this.label);
}

/// Profile Card - Shows user avatar, name, rating, and contact buttons
class ProfileCard extends StatelessWidget {
  final String? name;
  final String? phone;
  final String? imageUrl;
  final double? rating;
  final String label; // "الفني" or "العميل"
  final bool showContactButtons;

  const ProfileCard({
    super.key,
    this.name,
    this.phone,
    this.imageUrl,
    this.rating,
    this.label = 'المستخدم',
    this.showContactButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32.r,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null
                ? Icon(Icons.person, color: AppTheme.primaryColor, size: 32.s)
                : null,
          ),
          SizedBox(width: 16.w),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.fz, color: Colors.white60),
                ),
                SizedBox(height: 4.h),
                Text(
                  name ?? 'غير معروف',
                  style: TextStyle(
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (rating != null) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < rating!.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16.s,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12.fz,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Contact Buttons
          if (showContactButtons && phone != null) ...[
            IconButton(
              onPressed: () => _makeCall(phone!),
              icon: Container(
                padding: EdgeInsets.all(10.w),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone, color: Colors.white, size: 20.s),
              ),
            ),
            IconButton(
              onPressed: () => _sendWhatsApp(phone!),
              icon: Container(
                padding: EdgeInsets.all(10.w),
                decoration: const BoxDecoration(
                  color: Color(0xFF25D366),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat, color: Colors.white, size: 20.s),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Price Card - Shows price breakdown
class PriceCard extends StatelessWidget {
  final double? initialPrice;
  final double? proposedPrice;
  final double? finalPrice;
  final double commissionRate;
  final bool showBreakdown;

  const PriceCard({
    super.key,
    this.initialPrice,
    this.proposedPrice,
    this.finalPrice,
    this.commissionRate = 0.10,
    this.showBreakdown = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = finalPrice ?? proposedPrice ?? initialPrice ?? 0;
    final commission = displayPrice * commissionRate;
    final technicianEarnings = displayPrice - commission;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
        children: [
          // Main Price
          Text(
            '${displayPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 48.fz,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            'ريال',
            style: TextStyle(fontSize: 18.fz, color: Colors.white60),
          ),

          if (showBreakdown) ...[
            SizedBox(height: 16.h),
            Divider(color: Colors.white24),
            SizedBox(height: 12.h),

            // Breakdown
            _buildRow('سعر الخدمة', displayPrice),
            SizedBox(height: 8.h),
            _buildRow(
              'عمولة المنصة (${(commissionRate * 100).toInt()}%)',
              -commission,
              isNegative: true,
            ),
            SizedBox(height: 8.h),
            Divider(color: Colors.white24),
            SizedBox(height: 8.h),
            _buildRow(
              'صافي الأرباح',
              technicianEarnings,
              isBold: true,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount, {
    bool isNegative = false,
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.fz,
            color: Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${isNegative ? "-" : ""}${amount.abs().toStringAsFixed(0)} ر.س',
          style: TextStyle(
            fontSize: 14.fz,
            color: color ?? (isNegative ? Colors.red : Colors.white),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Job Timeline - Shows progress through job states
class JobTimeline extends StatelessWidget {
  final String currentStatus;

  const JobTimeline({super.key, required this.currentStatus});

  static const _steps = [
    ('pending', 'تم الإنشاء', Icons.add_circle),
    ('accepted', 'تم القبول', Icons.check_circle),
    ('price_pending', 'السعر', Icons.attach_money),
    ('in_progress', 'جاري التنفيذ', Icons.engineering),
    ('completed', 'مكتمل', Icons.done_all),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((s) => s.$1 == currentStatus);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_steps.length, (index) {
          final step = _steps[index];
          final isCompleted = index <= currentIndex;
          final isCurrent = index == currentIndex;

          return Column(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.primaryColor
                      : Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: AppTheme.primaryColor, width: 2)
                      : null,
                ),
                child: Icon(
                  step.$3,
                  color: isCompleted ? Colors.white : Colors.white38,
                  size: 20.s,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                step.$2,
                style: TextStyle(
                  fontSize: 10.fz,
                  color: isCompleted ? Colors.white : Colors.white38,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Elapsed Timer Widget - Shows time since a given timestamp
class ElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  final TextStyle? style;

  const ElapsedTimer({super.key, required this.startTime, this.style});

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  late Stream<int> _timerStream;

  @override
  void initState() {
    super.initState();
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _timerStream,
      builder: (context, snapshot) {
        final elapsed = DateTime.now().difference(widget.startTime);
        final hours = elapsed.inHours;
        final minutes = elapsed.inMinutes % 60;
        final seconds = elapsed.inSeconds % 60;

        final timeString = hours > 0
            ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
            : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Text(
          timeString,
          style:
              widget.style ??
              TextStyle(
                fontSize: 32.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}
