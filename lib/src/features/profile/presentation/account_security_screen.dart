import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../core/design/kadmat_tokens.dart';
import 'widgets/change_password_dialog.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('أمان الحساب'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 920.w),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                const _HeroCard(),
                SizedBox(height: 16.h),
                const _InfoCard(
                  icon: Icons.track_changes_outlined,
                  title: 'الخطوة الأهم الآن',
                  description:
                      'الميزة الوحيدة المتاحة حاليًا هنا هي تغيير كلمة المرور. بقية عناصر الأمان موضحة كخطة قادمة وليست أزرارًا ناقصة.',
                ),
                SizedBox(height: 16.h),
                const _SectionLabel(
                  title: 'المتاح الآن',
                  subtitle:
                      'الإجراء الفعلي الذي يمكنك استخدامه مباشرة لحماية حسابك.',
                ),
                SizedBox(height: 10.h),
                _Surface(
                  child: _SecurityOption(
                    title: 'تغيير كلمة المرور',
                    subtitle:
                        'حدّث كلمة المرور إذا استخدمت جهازًا جديدًا أو شككت في أمان الحساب.',
                    icon: Icons.lock_outline,
                    iconColor: Colors.green,
                    onTap: () => ChangePasswordDialog.show(context),
                  ),
                ),
                SizedBox(height: 16.h),
                const _SectionLabel(
                  title: 'لاحقًا',
                  subtitle:
                      'ميزات مخطط لها فقط، وليست متاحة بعد في هذه النسخة.',
                ),
                SizedBox(height: 10.h),
                const _Surface(
                  child: Column(
                    children: [
                      _SecurityOption(
                        title: 'المصادقة الثنائية (2FA)',
                        subtitle: 'ستضيف رمز تحقق إضافيًا عند تسجيل الدخول.',
                        icon: Icons.verified_user_outlined,
                        iconColor: Colors.orange,
                        enabled: false,
                        badgeLabel: 'لاحقًا',
                      ),
                      _DividerLine(),
                      _SecurityOption(
                        title: 'الأجهزة المتصلة',
                        subtitle:
                            'ستعرض الجلسات النشطة مع إمكانية تسجيل الخروج منها.',
                        icon: Icons.devices_outlined,
                        iconColor: Colors.orange,
                        enabled: false,
                        badgeLabel: 'لاحقًا',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                const _Surface(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: KadmatColors.brandPrimary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذه الشاشة تعرض حالة الأمان الفعلية فقط. لن نضيف عناصر تفاعلية هنا قبل أن تكون مدعومة بالكامل من الباكند والواجهة.',
                          style: TextStyle(
                            color: KadmatColors.lightTextSecondary,
                            height: 1.55,
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
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17313B), Color(0xFF0D1E25)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(Icons.shield_outlined, color: Colors.white, size: 22.s),
          ),
          SizedBox(height: 14.h),
          Text(
            'أبقِ أمان الحساب بسيطًا وواضحًا',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'المطلوب هنا ليس كثرة الخيارات، بل معرفة ما هو مدعوم الآن وما هو مؤجل حتى لا تضيع وقتك داخل إعدادات غير جاهزة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandAccent,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: KadmatColors.brandSecondary, size: 22.s),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: KadmatColors.lightTextPrimary,
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.5.fz,
                    height: 1.55,
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

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Divider(height: 1, color: KadmatColors.lightBorder),
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
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18.r),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: iconColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5.fz,
                          color: enabled
                              ? KadmatColors.lightTextPrimary
                              : KadmatColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    if (badgeLabel != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: KadmatColors.brandAccent,
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: TextStyle(
                            fontSize: 11.fz,
                            color: KadmatColors.lightTextSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: enabled
                        ? KadmatColors.lightTextSecondary
                        : KadmatColors.lightTextSecondary.withValues(
                            alpha: 0.9,
                          ),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            SizedBox(width: 10.w),
            Icon(
              Icons.chevron_left_rounded,
              color: KadmatColors.lightTextSecondary,
              size: 22.s,
            ),
          ],
        ],
      ),
    );
  }
}
