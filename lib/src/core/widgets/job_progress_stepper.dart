import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../app_theme.dart';

/// حالات الخطوة في Stepper
enum StepStatus { completed, current, upcoming }

/// خطوة واحدة في مسار الطلب
class JobStep {
  final String title;
  final String? subtitle;
  final IconData icon;
  final StepStatus status;

  const JobStep({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.status,
  });
}

/// Widget يعرض مراحل الطلب بشكل مرئي واضح
class JobProgressStepper extends StatelessWidget {
  final List<JobStep> steps;
  final bool isHorizontal;

  const JobProgressStepper({
    super.key,
    required this.steps,
    this.isHorizontal = false,
  });

  /// إنشاء stepper للعميل بناءً على حالة الطلب
  factory JobProgressStepper.forCustomer(
    String jobStatus, {
    bool isHorizontal = false,
  }) {
    final statusIndex = _getCustomerStatusIndex(jobStatus);

    return JobProgressStepper(
      isHorizontal: isHorizontal,
      steps: [
        JobStep(
          title: 'طلب الخدمة',
          subtitle: 'تم إرسال طلبك',
          icon: Icons.send_rounded,
          status: _getStepStatus(0, statusIndex),
        ),
        JobStep(
          title: 'انتظار الفني',
          subtitle: 'جاري البحث عن فني قريب',
          icon: Icons.search_rounded,
          status: _getStepStatus(1, statusIndex),
        ),
        JobStep(
          title: 'مراجعة السعر',
          subtitle: 'الفني اقترح سعراً',
          icon: Icons.attach_money_rounded,
          status: _getStepStatus(2, statusIndex),
        ),
        JobStep(
          title: 'تنفيذ الخدمة',
          subtitle: 'الفني في الطريق',
          icon: Icons.build_rounded,
          status: _getStepStatus(3, statusIndex),
        ),
        JobStep(
          title: 'التقييم',
          subtitle: 'قيّم تجربتك',
          icon: Icons.star_rounded,
          status: _getStepStatus(4, statusIndex),
        ),
      ],
    );
  }

  /// إنشاء stepper للفني بناءً على حالة الطلب
  factory JobProgressStepper.forTechnician(
    String jobStatus, {
    bool isHorizontal = false,
  }) {
    final statusIndex = _getTechnicianStatusIndex(jobStatus);

    return JobProgressStepper(
      isHorizontal: isHorizontal,
      steps: [
        JobStep(
          title: 'قبول الطلب',
          subtitle: 'تم قبول الطلب',
          icon: Icons.check_circle_rounded,
          status: _getStepStatus(0, statusIndex),
        ),
        JobStep(
          title: 'تحديد السعر',
          subtitle: 'اقترح سعراً للعميل',
          icon: Icons.price_change_rounded,
          status: _getStepStatus(1, statusIndex),
        ),
        JobStep(
          title: 'موافقة العميل',
          subtitle: 'انتظار الموافقة على السعر',
          icon: Icons.hourglass_top_rounded,
          status: _getStepStatus(2, statusIndex),
        ),
        JobStep(
          title: 'تنفيذ الخدمة',
          subtitle: 'ابدأ العمل',
          icon: Icons.handyman_rounded,
          status: _getStepStatus(3, statusIndex),
        ),
        JobStep(
          title: 'إكمال وتحصيل',
          subtitle: 'أنهِ الخدمة واستلم الدفع',
          icon: Icons.done_all_rounded,
          status: _getStepStatus(4, statusIndex),
        ),
      ],
    );
  }

  static int _getCustomerStatusIndex(String status) {
    switch (status) {
      case 'pending':
      case 'searching':
        return 1;
      case 'accepted':
        return 1;
      case 'price_pending':
      case 'counter_offer':
        return 2;
      case 'on_the_way':
      case 'arrived':
      case 'in_progress':
        return 3;
      case 'pending_confirm':
      case 'pending_confirmation':
      case 'completed':
        return 4;
      case 'rated':
        return 5;
      default:
        return 0;
    }
  }

  static int _getTechnicianStatusIndex(String status) {
    switch (status) {
      case 'accepted':
        return 1;
      case 'price_pending':
        return 2;
      case 'counter_offer':
        return 2;
      case 'on_the_way':
      case 'arrived':
      case 'in_progress':
        return 3;
      case 'pending_confirm':
      case 'pending_confirmation':
      case 'completed':
      case 'rated':
        return 5;
      default:
        return 0;
    }
  }

  static StepStatus _getStepStatus(int stepIndex, int currentIndex) {
    if (stepIndex < currentIndex) return StepStatus.completed;
    if (stepIndex == currentIndex) return StepStatus.current;
    return StepStatus.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return _buildHorizontalStepper(context);
    }
    return _buildVerticalStepper(context);
  }

  Widget _buildVerticalStepper(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator column
            Column(
              children: [
                _buildStepCircle(step.status, step.icon),
                if (!isLast) _buildConnectorLine(step.status),
              ],
            ),
            SizedBox(width: 16.w),
            // Step content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h),
                child: _buildStepContent(step, context),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHorizontalStepper(BuildContext context) {
    return SizedBox(
      height: 80.h,
      child: Row(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStepCircle(step.status, step.icon, small: true),
                      SizedBox(height: 8.h),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.fz,
                          fontWeight: step.status == StepStatus.current
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _getStatusColor(step.status),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) _buildHorizontalConnector(step.status),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepCircle(
    StepStatus status,
    IconData icon, {
    bool small = false,
  }) {
    final size = small ? 32.w : 48.w;
    final iconSize = small ? 16.s : 24.s;

    Color backgroundColor;
    Color iconColor;

    switch (status) {
      case StepStatus.completed:
        backgroundColor = Colors.green;
        iconColor = Colors.white;
        break;
      case StepStatus.current:
        backgroundColor = AppTheme.primaryColor;
        iconColor = Colors.white;
        break;
      case StepStatus.upcoming:
        backgroundColor = Colors.grey.withValues(alpha: 0.2);
        iconColor = Colors.grey;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: status == StepStatus.current
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 12.r,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        status == StepStatus.completed ? Icons.check : icon,
        color: iconColor,
        size: iconSize,
      ),
    );
  }

  Widget _buildConnectorLine(StepStatus status) {
    return Container(
      width: 2.w,
      height: 40.h,
      color: status == StepStatus.completed
          ? Colors.green
          : Colors.grey.withValues(alpha: 0.3),
    );
  }

  Widget _buildHorizontalConnector(StepStatus status) {
    return Expanded(
      child: Container(
        height: 2.h,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        color: status == StepStatus.completed
            ? Colors.green
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStepContent(JobStep step, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: TextStyle(
            fontSize: 16.fz,
            fontWeight: step.status == StepStatus.current
                ? FontWeight.bold
                : FontWeight.w500,
            color: _getStatusColor(step.status),
          ),
        ),
        if (step.subtitle != null) ...[
          SizedBox(height: 4.h),
          Text(
            step.subtitle!,
            style: TextStyle(
              fontSize: 13.fz,
              color: step.status == StepStatus.upcoming
                  ? Colors.grey
                  : Colors.grey[600],
            ),
          ),
        ],
        if (step.status == StepStatus.current) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              '← أنت هنا',
              style: TextStyle(
                fontSize: 12.fz,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.completed:
        return Colors.green;
      case StepStatus.current:
        return Colors.white;
      case StepStatus.upcoming:
        return Colors.grey;
    }
  }
}
