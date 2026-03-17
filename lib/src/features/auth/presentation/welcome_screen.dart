import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'widgets/oauth_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1624), Color(0xFF132238), Color(0xFFF5F7FA)],
            stops: [0, 0.38, 0.38],
          ),
        ),
        child: Stack(
          children: [
            const _WelcomeBackdrop(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 620.w),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopUtilityRow(
                          onLogin: () => context.push(AppRoutes.login),
                        ),
                        SizedBox(height: 18.h),
                        _HeroPanel(
                          onCreateAccount: () =>
                              context.push(AppRoutes.register),
                          onTechnicianLanding: () =>
                              context.push(AppRoutes.technicianLanding),
                        ),
                        SizedBox(height: 20.h),
                        const _DecisionHeader(),
                        SizedBox(height: 14.h),
                        _RoleDecisionCard(
                          icon: Icons.person_rounded,
                          accent: KadmatColors.brandPrimary,
                          title: 'أنا عميل',
                          subtitle:
                              'اطلب خدمة بسرعة، استقبل العروض، وتابع التنفيذ بخطوات واضحة من البداية للنهاية.',
                          bullets: const [
                            'طلب خدمة جديد',
                            'مقارنة العروض بسهولة',
                            'متابعة، صور، ورسائل بعد قبول العرض',
                          ],
                          primaryLabel: 'ابدأ كعميل',
                          secondaryLabel: 'لدي حساب عميل',
                          onPrimary: () => context.push(AppRoutes.register),
                          onSecondary: () => context.push(AppRoutes.login),
                        ),
                        SizedBox(height: 14.h),
                        _RoleDecisionCard(
                          icon: Icons.engineering_rounded,
                          accent: const Color(0xFFFFA53A),
                          title: 'أنا فني',
                          subtitle:
                              'ادخل إلى مساحة العمل المهنية لإدارة الطلبات، التسعير، التنفيذ، والمحفظة بدون تعقيد.',
                          bullets: const [
                            'طلبات قريبة وواضحة',
                            'تسعير وتنفيذ بخطوات منظمة',
                            'ملف مهني ومحفظة وإشعارات',
                          ],
                          primaryLabel: 'الدخول لمساحة الفني',
                          secondaryLabel: 'تسجيل فني جديد',
                          onPrimary: () =>
                              context.push(AppRoutes.technicianLanding),
                          onSecondary: () =>
                              context.push(AppRoutes.technicianRegister),
                        ),
                        SizedBox(height: 16.h),
                        _TrustStrip(
                          onSocial: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OAuthLoginScreen(),
                              ),
                            );
                          },
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

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80.h,
            right: -40.w,
            child: _GlowOrb(
              size: 240.w,
              color: KadmatColors.brandPrimary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            top: 120.h,
            left: -70.w,
            child: _GlowOrb(
              size: 180.w,
              color: const Color(0xFF7AD6FF).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 260.h,
            right: -90.w,
            child: _GlowOrb(
              size: 220.w,
              color: const Color(0xFFFFA53A).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopUtilityRow extends StatelessWidget {
  const _TopUtilityRow({required this.onLogin});

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF6FD9FF),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Kadmat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5.fz,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
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
    required this.onCreateAccount,
    required this.onTechnicianLanding,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onTechnicianLanding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34.r),
        color: const Color(0xFF111B2B),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28.r,
            offset: Offset(0, 18.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroMark(),
          SizedBox(height: 20.h),
          Text(
            'اطلب فنيًا موثوقًا في دقائق.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30.fz,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'تجربة بسيطة للعميل، ومساحة عمل واضحة للفني. من إنشاء الطلب إلى التقييم، كل مرحلة لها خطوة تالية مفهومة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.2.fz,
              height: 1.65,
            ),
          ),
          SizedBox(height: 18.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: const [
              _HeroPill(
                icon: Icons.bolt_rounded,
                label: 'عروض فنيين قريبين',
              ),
              _HeroPill(
                icon: Icons.photo_library_outlined,
                label: 'صور قبل وبعد',
              ),
              _HeroPill(
                icon: Icons.verified_user_outlined,
                label: 'تقييمات وملفات موثقة',
              ),
            ],
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
                      label: 'ابدأ الآن',
                      icon: Icons.arrow_back_rounded,
                      onPressed: onCreateAccount,
                    ),
                    SizedBox(height: 10.h),
                    KadmatSecondaryButton(
                      label: 'مساحة الفني',
                      icon: Icons.engineering_rounded,
                      onPressed: onTechnicianLanding,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: KadmatPrimaryButton(
                      label: 'ابدأ الآن',
                      icon: Icons.arrow_back_rounded,
                      onPressed: onCreateAccount,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: KadmatSecondaryButton(
                      label: 'مساحة الفني',
                      icon: Icons.engineering_rounded,
                      onPressed: onTechnicianLanding,
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

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 176.w,
        height: 176.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 128.w,
                height: 128.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34.r),
                  color: const Color(0xFF17304B),
                  border: Border.all(
                    color: KadmatColors.brandPrimary.withValues(alpha: 0.32),
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: 0.18,
              child: Container(
                width: 116.w,
                height: 116.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF223754), Color(0xFF0A1018)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KadmatColors.brandPrimary.withValues(alpha: 0.14),
                      blurRadius: 30.r,
                      offset: Offset(0, 12.h),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 26.h,
                      child: Container(
                        width: 22.w,
                        height: 22.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB24E),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.home_repair_service_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    Positioned(
                      bottom: 22.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: KadmatColors.brandPrimary.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          'طلب واضح',
                          style: TextStyle(
                            color: const Color(0xFF8DE5FF),
                            fontSize: 11.fz,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionHeader extends StatelessWidget {
  const _DecisionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختر المسار المناسب لك',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'صممنا شاشة البداية لتوصلك مباشرة إلى ما تريد، بدون قوائم إضافية أو تشتت في أول استخدام.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: KadmatColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDecisionCard extends StatelessWidget {
  const _RoleDecisionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54.w,
                height: 54.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Icon(icon, color: accent, size: 28.s),
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
                        fontSize: 21.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: KadmatColors.lightTextSecondary,
                        fontSize: 13.fz,
                        height: 1.62,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFB),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFE5EEF1)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < bullets.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 4.h),
                        width: 18.w,
                        height: 18.w,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: accent,
                          size: 12.s,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          bullets[i],
                          style: TextStyle(
                            color: KadmatColors.lightTextPrimary,
                            fontSize: 13.fz,
                            fontWeight: FontWeight.w600,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i != bullets.length - 1) SizedBox(height: 10.h),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.h),
          KadmatPrimaryButton(
            label: primaryLabel,
            icon: Icons.arrow_back_rounded,
            onPressed: onPrimary,
            backgroundColor: accent,
            foregroundColor: accent.computeLuminance() > 0.5
                ? const Color(0xFF0C171C)
                : Colors.white,
          ),
          SizedBox(height: 10.h),
          KadmatSecondaryButton(
            label: secondaryLabel,
            icon: Icons.login_rounded,
            onPressed: onSecondary,
          ),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.onSocial});

  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
            child: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFFE08A18),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دخول اجتماعي سريع',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'إذا رغبت، يمكنك استخدام Google أو Apple للبدء بسرعة، ثم يكمل التطبيق نفس الفلو المنظم بعد ذلك.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSocial,
            child: const Text('Google / Apple'),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.s, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.fz,
              fontWeight: FontWeight.w700,
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
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80.r,
            spreadRadius: 10.r,
          ),
        ],
      ),
    );
  }
}
