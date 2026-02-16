import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/features/auth/data/auth_repository.dart';
import 'package:kadmat/src/features/profile/presentation/widgets/change_password_dialog.dart';

class TechnicianSettingsScreen extends ConsumerWidget {
  const TechnicianSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final userId = userProfile?['id'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الفني')),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildTile(
            context,
            icon: Icons.person_outline,
            title: 'الملف الشخصي',
            subtitle: 'عرض وتحديث بياناتك المهنية',
            onTap: () {
              if (userId == null || userId.isEmpty) return;
              context.push(AppRoutes.buildTechnicianProfilePath(userId));
            },
          ),
          _buildTile(
            context,
            icon: Icons.lock_outline,
            title: 'تغيير كلمة المرور',
            subtitle: 'تحديث كلمة المرور لحماية الحساب',
            onTap: () {
              ChangePasswordDialog.show(context);
            },
          ),
          _buildTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'الإشعارات',
            subtitle: 'إدارة إشعارات الطلبات والرسائل',
            onTap: () => context.push(AppRoutes.notifications),
          ),
          _buildTile(
            context,
            icon: Icons.location_on_outlined,
            title: 'صلاحيات الموقع',
            subtitle: 'فتح إعدادات الموقع في الجهاز',
            onTap: () => _openLocationSettings(context),
          ),
          _buildTile(
            context,
            icon: Icons.logout,
            title: 'تسجيل الخروج',
            subtitle: 'الخروج من حساب الفني',
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.fz,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12.fz, color: Colors.grey.shade400),
        ),
        trailing: Icon(Icons.chevron_right, size: 20.s),
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
