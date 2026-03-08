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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1A1F), Color(0xFF132730), Color(0xFFF2F6F7)],
            stops: [0, 0.42, 0.42],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroHeader(
                  onCreateAccount: () => context.push(AppRoutes.register),
                  onLogin: () => context.push(AppRoutes.login),
                  onTechnician: () => context.push(AppRoutes.technicianLanding),
                ),
                SizedBox(height: 22.h),
                const _JourneyStrip(),
                SizedBox(height: 20.h),
                _FeatureGrid(
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
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.onCreateAccount,
    required this.onLogin,
    required this.onTechnician,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;
  final VoidCallback onTechnician;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17303A), Color(0xFF102127)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36.h,
            right: -24.w,
            child: _GlowBlob(
              size: 160.w,
              color: KadmatColors.brandPrimary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: -28.h,
            left: -8.w,
            child: _GlowBlob(
              size: 110.w,
              color: const Color(0xFFFFA33A).withValues(alpha: 0.22),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(22.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 7.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    'Kadmat • خدمة ميدانية منظمة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.fz,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'اطلب فنيًا قريبًا وأنهِ الخدمة بثقة.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31.fz,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'واجهة واحدة للطلب، العروض، المتابعة، الصور، التقييم، والإشعارات. سهلة للعميل وواضحة للفني من أول خطوة.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14.fz,
                    height: 1.65,
                  ),
                ),
                SizedBox(height: 18.h),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: const [
                    _MetricChip(label: 'عروض فنيين قريبين', icon: Icons.bolt),
                    _MetricChip(
                      label: 'صور قبل وبعد',
                      icon: Icons.photo_library_outlined,
                    ),
                    _MetricChip(
                      label: 'تقييمات موثقة',
                      icon: Icons.star_rounded,
                    ),
                  ],
                ),
                SizedBox(height: 22.h),
                KadmatPrimaryButton(
                  label: 'ابدأ كعميل',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onCreateAccount,
                ),
                SizedBox(height: 10.h),
                KadmatSecondaryButton(
                  label: 'لديك حساب؟ تسجيل الدخول',
                  icon: Icons.login_rounded,
                  onPressed: onLogin,
                ),
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFA33A,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: const Icon(
                          Icons.engineering_rounded,
                          color: Color(0xFFFFC36F),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'هل أنت فني؟',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.fz,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'ادخل لمساحة الفني لإدارة الطلبات، المحفظة، والحساب المهني.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12.fz,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onTechnician,
                        child: const Text('مساحة الفني'),
                      ),
                    ],
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

class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'اختر الخدمة', 'ابدأ بطلب واضح ومباشر'),
      ('2', 'استقبل العروض', 'قارن الفنيين بسرعة'),
      ('3', 'تابع التنفيذ', 'رسائل وصور وحالة محدثة'),
    ];

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رحلة استخدام بسيطة',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8.h),
          Text(
            'صممنا Kadmat ليقلل الخطوات ويجعل كل مرحلة واضحة للعميل والفني.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: 16.h),
          for (var i = 0; i < steps.length; i++) ...[
            _TimelineStep(
              number: steps[i].$1,
              title: steps[i].$2,
              subtitle: steps[i].$3,
            ),
            if (i != steps.length - 1) SizedBox(height: 12.h),
          ],
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.onSocial});

  final VoidCallback onSocial;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        title: 'تواصل مضبوط',
        subtitle: 'الرسائل والمكالمات بعد قبول العرض فقط.',
        icon: Icons.chat_bubble_outline_rounded,
        color: KadmatColors.brandPrimary,
      ),
      (
        title: 'خطوات موثقة',
        subtitle: 'صور قبل وبعد الخدمة وتاريخ واضح للتحديثات.',
        icon: Icons.assignment_turned_in_outlined,
        color: KadmatColors.stateSuccess,
      ),
      (
        title: 'حسابات موثقة',
        subtitle: 'ملف مهني للفني ومراجعات موحدة عبر الشاشات.',
        icon: Icons.verified_user_outlined,
        color: KadmatColors.stateInfo,
      ),
    ];

    return Column(
      children: [
        for (final card in cards) ...[
          _FeatureCard(
            title: card.title,
            subtitle: card.subtitle,
            icon: card.icon,
            color: card.color,
          ),
          SizedBox(height: 12.h),
        ],
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EA),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: const Color(0xFFF5D9A7)),
          ),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA33A).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(
                  Icons.alternate_email_rounded,
                  color: Color(0xFFE0871C),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل سريع',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'إذا أردت المتابعة بحساب اجتماعي، ستختار المزود في الشاشة التالية.',
                      style: Theme.of(context).textTheme.bodyMedium,
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
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999.r),
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

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KadmatColors.brandAccent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: KadmatColors.brandSecondary,
              fontSize: 13.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 2.h),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
