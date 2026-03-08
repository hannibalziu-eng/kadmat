import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';

class TechnicianLandingScreen extends StatelessWidget {
  const TechnicianLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  SizedBox(height: 18.h),
                  const _FocusCard(
                    icon: Icons.track_changes_outlined,
                    title: 'ما الذي ستفعله هنا؟',
                    description:
                        'أنشئ حساب الفني مرة واحدة، أضف تخصصك ومستنداتك، ثم ابدأ استقبال الطلبات القريبة من لوحة واحدة واضحة.',
                  ),
                  SizedBox(height: 18.h),
                  _SectionLabel(
                    title: 'كيف تبدأ',
                    subtitle:
                        'ثلاث خطوات فقط للوصول إلى الحساب التشغيلي الكامل.',
                  ),
                  SizedBox(height: 12.h),
                  const _StepCard(
                    number: '1',
                    icon: Icons.badge_outlined,
                    title: 'أنشئ حساب الفني',
                    description:
                        'ابدأ ببياناتك الأساسية حتى نفتح لك مساحة العمل الخاصة بالفني داخل التطبيق.',
                  ),
                  SizedBox(height: 12.h),
                  const _StepCard(
                    number: '2',
                    icon: Icons.handyman_outlined,
                    title: 'اختر التخصص والخبرة',
                    description:
                        'حدّد مجالات الخدمة التي تنفذها حتى تظهر لك الطلبات المناسبة فقط.',
                  ),
                  SizedBox(height: 12.h),
                  const _StepCard(
                    number: '3',
                    icon: Icons.verified_user_outlined,
                    title: 'أكمل التحقق المهني',
                    description:
                        'أضف المستندات المطلوبة لبناء الثقة مع العميل وتفعيل الحساب بشكل صحيح.',
                  ),
                  SizedBox(height: 18.h),
                  const _FocusCard(
                    icon: Icons.info_outline,
                    title: 'قبل أن تضغط تسجيل',
                    description:
                        'إذا كان لديك حساب فني سابق، لا تنشئ حسابًا جديدًا. ادخل مباشرة إلى شاشة تسجيل الدخول.',
                  ),
                  SizedBox(height: 22.h),
                  KadmatPrimaryButton(
                    label: 'ابدأ تسجيل الفني',
                    icon: Icons.app_registration_rounded,
                    onPressed: () => context.push(AppRoutes.technicianRegister),
                  ),
                  SizedBox(height: 12.h),
                  KadmatSecondaryButton(
                    label: 'لدي حساب فني بالفعل',
                    icon: Icons.login_rounded,
                    onPressed: () => context.push(AppRoutes.technicianLogin),
                  ),
                ],
              ),
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
      padding: EdgeInsets.all(22.w),
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
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.engineering_rounded,
              color: Colors.white,
              size: 26.s,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'ادخل Kadmat كفني محترف',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'هذه المساحة مخصصة للفني الذي يريد إدارة الطلبات، التسعير، المتابعة، والمحفظة من تجربة تشغيلية بسيطة ومباشرة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.fz,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    fontSize: 12.6.fz,
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
            fontSize: 17.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 12.6.fz,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: KadmatColors.brandPrimary,
                  fontSize: 16.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: KadmatColors.brandSecondary, size: 18.s),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 14.6.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  description,
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.6.fz,
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
