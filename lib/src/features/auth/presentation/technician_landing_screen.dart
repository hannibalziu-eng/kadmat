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
    const accent = Color(0xFFFFA53A);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121824), Color(0xFF1B2433), Color(0xFFF5F7FA)],
            stops: [0, 0.34, 0.34],
          ),
        ),
        child: Stack(
          children: [
            const _Backdrop(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 640.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopRow(
                          onLogin: () => context.push(AppRoutes.technicianLogin),
                        ),
                        SizedBox(height: 18.h),
                        _HeroPanel(
                          accent: accent,
                          onRegister: () =>
                              context.push(AppRoutes.technicianRegister),
                          onLogin: () =>
                              context.push(AppRoutes.technicianLogin),
                        ),
                        SizedBox(height: 20.h),
                        const _DecisionBlock(
                          title: 'كيف تبدأ كفني',
                          subtitle:
                              'المسار هنا مهني ومباشر: أنشئ الحساب، أكمل التخصص والمستندات، ثم ابدأ استقبال الطلبات المناسبة فقط.',
                        ),
                        SizedBox(height: 14.h),
                        _StepSurface(
                          accent: accent,
                          number: '1',
                          title: 'أنشئ حساب الفني',
                          description:
                              'ابدأ ببياناتك الأساسية حتى نفتح لك مساحة العمل التشغيلية داخل التطبيق.',
                          icon: Icons.badge_outlined,
                        ),
                        SizedBox(height: 12.h),
                        _StepSurface(
                          accent: accent,
                          number: '2',
                          title: 'حدد التخصص والخبرة',
                          description:
                              'اختر مجالات الخدمة التي تنفذها حتى ترى الطلبات التي تناسبك فقط.',
                          icon: Icons.handyman_outlined,
                        ),
                        SizedBox(height: 12.h),
                        _StepSurface(
                          accent: accent,
                          number: '3',
                          title: 'ارفع المستندات المطلوبة',
                          description:
                              'وثّق حسابك من البداية حتى لا تتوقف عند المراجعة أو التفعيل لاحقًا.',
                          icon: Icons.verified_user_outlined,
                        ),
                        SizedBox(height: 16.h),
                        const _InfoSurface(
                          icon: Icons.info_outline,
                          title: 'قبل أن تبدأ',
                          description:
                              'إذا كان لديك حساب فني سابق، لا تنشئ حسابًا جديدًا. ادخل مباشرة إلى شاشة تسجيل الدخول حتى لا تتكرر بياناتك.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            'مساحة الفني',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onLogin,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
          child: Text(
            'تسجيل الدخول',
            style: TextStyle(fontSize: 13.fz, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.accent,
    required this.onRegister,
    required this.onLogin,
  });

  final Color accent;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34.r),
        color: const Color(0xFF121A28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28.r,
            offset: Offset(0, 18.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.engineering_rounded, color: Colors.white, size: 28.s),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: const [
              _Pill(label: 'طلبات أوضح'),
              _Pill(label: 'تسعير وتنفيذ منظم'),
              _Pill(label: 'محفظة ومتابعة'),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'ادخل Kadmat كفني محترف.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30.fz,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'هذه المساحة مبنية لتقودك من استقبال الطلب حتى الإكمال والمحفظة بخطوات واضحة، لا بقوائم مزدحمة أو قرارات مبهمة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.2.fz,
              height: 1.62,
            ),
          ),
          SizedBox(height: 20.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 430;
              if (shouldStack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KadmatPrimaryButton(
                      label: 'ابدأ تسجيل الفني',
                      icon: Icons.app_registration_rounded,
                      onPressed: onRegister,
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF111827),
                    ),
                    SizedBox(height: 10.h),
                    KadmatSecondaryButton(
                      label: 'لدي حساب فني',
                      icon: Icons.login_rounded,
                      onPressed: onLogin,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: KadmatPrimaryButton(
                      label: 'ابدأ تسجيل الفني',
                      icon: Icons.app_registration_rounded,
                      onPressed: onRegister,
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: KadmatSecondaryButton(
                      label: 'لدي حساب فني',
                      icon: Icons.login_rounded,
                      onPressed: onLogin,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DecisionBlock extends StatelessWidget {
  const _DecisionBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: KadmatColors.lightTextSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepSurface extends StatelessWidget {
  const _StepSurface({
    required this.accent,
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final Color accent;
  final String number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 22.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: accent, size: 22.s),
                Positioned(
                  top: 4.h,
                  left: 4.w,
                  child: Container(
                    width: 16.w,
                    height: 16.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      number,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
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
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.8.fz,
                    height: 1.58,
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

class _InfoSurface extends StatelessWidget {
  const _InfoSurface({
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
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFF4D39C)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFFA53A).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: const Color(0xFFE08A18), size: 22.s),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11.8.fz,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90.h,
            right: -50.w,
            child: _GlowOrb(
              size: 220.w,
              color: KadmatColors.brandPrimary.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 120.h,
            left: -70.w,
            child: _GlowOrb(
              size: 180.w,
              color: const Color(0xFFFFA53A).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0, 1],
        ),
      ),
    );
  }
}
