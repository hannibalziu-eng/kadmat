import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import 'package:kadmat/src/features/technician/domain/technician_status.dart';
import 'package:kadmat/src/features/technician/presentation/providers/technician_dispatch_feed_provider.dart';
import 'package:kadmat/src/features/technician/presentation/providers/technician_providers.dart';
import '../../../jobs/presentation/job_controller.dart';

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
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;

              try {
                await ref
                    .read(technicianOnlineStatusProvider.notifier)
                    .toggle();
                final becameOnline =
                    ref.read(technicianOnlineStatusProvider) ==
                    TechnicianStatus.online;

                if (becameOnline) {
                  try {
                    await LocationService().startTracking(userId);
                    await LocationService().setTrackingMode(
                      LocationTrackingMode.idle,
                    );
                    if (context.mounted) {
                      KadmatToast.showSuccess(
                        context,
                        title: 'أنت الآن متصل',
                        message: 'سيتم تحديث الطلبات القريبة تلقائياً.',
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      KadmatToast.showInfo(
                        context,
                        title: 'تم تفعيل الاتصال',
                        message:
                            'اسمح بالموقع أو حدده يدويًا من شاشة الطلبات لإظهار الطلبات القريبة.',
                      );
                    }
                  }
                } else {
                  await LocationService().stopTracking();
                  ref.read(technicianManualLocationProvider.notifier).state =
                      null;
                  if (context.mounted) {
                    KadmatToast.showInfo(
                      context,
                      title: 'تم قطع الاتصال',
                      message: 'لن تصلك طلبات جديدة حتى تعود إلى وضع المتصل.',
                    );
                  }
                }

                ref.invalidate(technicianResolvedLocationProvider);
                ref.invalidate(technicianDispatchFeedProvider);
                ref.invalidate(watchNearbyJobsStreamProvider);
              } catch (e) {
                if (context.mounted) {
                  final normalized = e.toString().toLowerCase();
                  final message = normalized.contains('permission')
                      ? 'تم تفعيل الاتصال، لكن يلزم السماح بالموقع أو تحديده يدويًا.'
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
