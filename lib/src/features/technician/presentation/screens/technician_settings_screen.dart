import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kadmat/src/core/design/kadmat_tokens.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/features/auth/data/auth_repository.dart';
import 'package:kadmat/src/features/profile/presentation/widgets/change_password_dialog.dart';
import 'package:kadmat/src/features/technician/presentation/widgets/technician_flow_widgets.dart';

class TechnicianSettingsScreen extends ConsumerWidget {
  const TechnicianSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final userId = userProfile?['id'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('إعدادات الفني')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 940.w),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                TechnicianFlowHero(
                  icon: Icons.settings_outlined,
                  eyebrow: 'إدارة الحساب',
                  title: 'رتّب إعداداتك بسرعة',
                  subtitle:
                      'أبقِ البيانات المهنية والصلاحيات الأساسية واضحة حتى لا يتعطل استقبال الطلبات أو الوصول إلى الإشعارات.',
                  bottom: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: const [
                      TechnicianFlowPill(
                        icon: Icons.person_outline,
                        label: 'بياناتك المهنية',
                      ),
                      TechnicianFlowPill(
                        icon: Icons.location_on_outlined,
                        label: 'الموقع والصلاحيات',
                      ),
                      TechnicianFlowPill(
                        icon: Icons.security_outlined,
                        label: 'حماية الحساب',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                const TechnicianFlowSurface(
                  child: TechnicianFlowNextStepCard(
                    icon: Icons.track_changes_outlined,
                    title: 'الخطوة الأهم الآن',
                    description:
                        'إذا تغيّرت خبراتك أو الخدمات التي تقدمها، ابدأ من الملف الشخصي. وإذا توقفت الطلبات، راجع صلاحيات الموقع والإشعارات قبل أي شيء آخر.',
                  ),
                ),
                SizedBox(height: 16.h),
                _SectionLabel(
                  title: 'الحساب والهوية المهنية',
                  subtitle: 'الإعدادات التي تؤثر مباشرة في ظهورك للعميل.',
                ),
                SizedBox(height: 10.h),
                _SettingsCard(
                  items: [
                    _SettingsItem(
                      icon: Icons.person_outline,
                      title: 'الملف الشخصي',
                      subtitle: 'عرض وتحديث بياناتك المهنية وخدماتك.',
                      onTap: () {
                        if (userId == null || userId.isEmpty) return;
                        context.push(
                          AppRoutes.buildTechnicianProfilePath(userId),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.lock_outline,
                      title: 'تغيير كلمة المرور',
                      subtitle: 'حدّث كلمة المرور للحفاظ على أمان الحساب.',
                      onTap: () => ChangePasswordDialog.show(context),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                _SectionLabel(
                  title: 'التشغيل اليومي',
                  subtitle:
                      'تأكد من أن الهاتف يملك ما يحتاجه التطبيق ليعمل بسلاسة.',
                ),
                SizedBox(height: 10.h),
                _SettingsCard(
                  items: [
                    _SettingsItem(
                      icon: Icons.notifications_outlined,
                      title: 'الإشعارات',
                      subtitle: 'راجع تنبيهات الطلبات والرسائل بسرعة.',
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                    _SettingsItem(
                      icon: Icons.location_on_outlined,
                      title: 'صلاحيات الموقع',
                      subtitle:
                          'افتح إعدادات الجهاز إذا توقفت الطلبات القريبة عن الظهور.',
                      onTap: () => _openLocationSettings(context),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                TechnicianFlowSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 16.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'استخدمه عند تبديل الجهاز أو إنهاء العمل على هذا الحساب.',
                        style: TextStyle(
                          color: KadmatColors.lightTextSecondary,
                          fontSize: 12.5.fz,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmSignOut(context, ref),
                          icon: const Icon(Icons.logout),
                          label: const Text('تسجيل الخروج من حساب الفني'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB23A48),
                            side: const BorderSide(color: Color(0xFFE8C8CE)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLocationSettings(BuildContext context) async {
    final openedLocation = await Geolocator.openLocationSettings();
    if (openedLocation) return;

    final openedApp = await openAppSettings();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          openedApp
              ? 'تم فتح إعدادات التطبيق للموقع.'
              : 'تعذر فتح إعدادات الموقع على هذا الجهاز.',
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب الفني؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: KadmatColors.lightTextPrimary,
            fontSize: 16.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 12.4.fz,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});

  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return TechnicianFlowSurface(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SettingsRow(item: items[i]),
            if (i != items.length - 1)
              Divider(height: 22.h, color: KadmatColors.lightBorder),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item});

  final _SettingsItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: KadmatColors.brandAccent,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                item.icon,
                color: KadmatColors.brandSecondary,
                size: 21.s,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 14.6.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: KadmatColors.lightTextSecondary,
                      fontSize: 12.3.fz,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Icon(
              Icons.chevron_left_rounded,
              color: KadmatColors.lightTextSecondary,
              size: 22.s,
            ),
          ],
        ),
      ),
    );
  }
}
