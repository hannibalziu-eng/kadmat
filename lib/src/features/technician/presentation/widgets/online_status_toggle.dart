import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import 'package:kadmat/src/features/technician/domain/technician_status.dart';
import 'package:kadmat/src/features/technician/presentation/providers/technician_providers.dart';

class OnlineStatusToggle extends ConsumerWidget {
  const OnlineStatusToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(technicianOnlineStatusProvider);
    final isOnline = status == TechnicianStatus.online;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: isOnline
                  ? KadmatColors.stateSuccess
                  : KadmatColors.lightTextSecondary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isOnline ? 'متصل الآن' : 'غير متصل',
                style: TextStyle(
                  color: KadmatColors.lightTextPrimary,
                  fontSize: 13.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                isOnline
                    ? 'تظهر لك الطلبات القريبة'
                    : 'فعّل الاتصال لاستقبال الطلبات',
                style: TextStyle(
                  color: KadmatColors.lightTextSecondary,
                  fontSize: 11.2.fz,
                ),
              ),
            ],
          ),
          SizedBox(width: 10.w),
          Switch.adaptive(
            value: isOnline,
            activeThumbColor: KadmatColors.stateSuccess,
            activeTrackColor: KadmatColors.stateSuccess.withValues(alpha: 0.35),
            onChanged: (_) async {
              try {
                await ref
                    .read(technicianOnlineStatusProvider.notifier)
                    .toggle();
              } catch (e) {
                if (context.mounted) {
                  final normalized = e.toString().toLowerCase();
                  final message = normalized.contains('permission')
                      ? 'تعذر تحديث الحالة. اسمح للموقع أولاً.'
                      : 'تعذر تحديث الحالة حالياً. حاول مرة أخرى.';
                  KadmatToast.showError(
                    context,
                    title: 'تعذر تحديث الحالة',
                    message: message,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
