import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import 'widgets/change_password_dialog.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'أمان الحساب',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _SecurityOverviewCard(),
          SizedBox(height: 20.h),
          _SecurityOption(
            title: 'تغيير كلمة المرور',
            subtitle: 'التحكم الوحيد المتاح الآن لتأمين حسابك',
            icon: Icons.lock_outline,
            iconColor: Colors.green,
            onTap: () => ChangePasswordDialog.show(context),
          ),
          SizedBox(height: 24.h),
          Text(
            'قيد الإعداد',
            style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          const _SecurityOption(
            title: 'المصادقة الثنائية (2FA)',
            subtitle: 'ستتطلب رمز تحقق إضافيًا عند تسجيل الدخول',
            icon: Icons.verified_user_outlined,
            iconColor: Colors.orange,
            enabled: false,
            badgeLabel: 'لاحقًا',
          ),
          SizedBox(height: 12.h),
          const _SecurityOption(
            title: 'الأجهزة المتصلة',
            subtitle: 'ستعرض الجلسات النشطة وإمكانية تسجيل الخروج منها',
            icon: Icons.devices_outlined,
            iconColor: Colors.orange,
            enabled: false,
            badgeLabel: 'لاحقًا',
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 18.s,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'يعرض هذا القسم حالة ميزات الأمان الفعلية فقط. لن تظهر خيارات تفاعلية إضافية هنا قبل أن تصبح مدعومة بالكامل في الباكند والواجهة.',
                    style: TextStyle(
                      fontSize: 13.fz,
                      height: 1.45,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
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

class _SecurityOverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.green,
                  size: 22.s,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الحماية الحالية',
                      style: TextStyle(
                        fontSize: 15.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'كلمة مرور الحساب مفعلة ويمكن تحديثها الآن',
                      style: TextStyle(fontSize: 13.fz, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  const _SecurityOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.enabled = true,
    this.badgeLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool enabled;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: enabled ? onTap : null,
      contentPadding: EdgeInsets.all(12.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: enabled ? null : Colors.white70,
              ),
            ),
          ),
          if (badgeLabel != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                badgeLabel!,
                style: TextStyle(fontSize: 11.fz, color: Colors.white54),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 6.h),
        child: Text(
          subtitle,
          style: TextStyle(color: enabled ? null : Colors.white54),
        ),
      ),
      trailing: enabled ? const Icon(Icons.chevron_right) : null,
    );
  }
}
