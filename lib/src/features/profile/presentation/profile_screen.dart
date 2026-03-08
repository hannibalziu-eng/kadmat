import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../wallet/domain/wallet.dart';
import '../../wallet/presentation/wallet_controller.dart';
import 'account_security_screen.dart';
import 'edit_profile_screen.dart';
import 'favorite_services_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final isGuest = authRepo.currentUser == 'guest';
    final userProfile = authRepo.userProfile;
    final fullName = (userProfile?['full_name'] as String?)?.trim();
    final phone = (userProfile?['phone'] as String?)?.trim();
    final profileImageUrl = userProfile?['profile_image_url']
        ?.toString()
        .trim();
    final walletAsync = isGuest ? null : ref.watch(myWalletProvider);
    final wallet = walletAsync?.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
          child: Column(
            children: [
              _buildHero(
                context,
                ref,
                isGuest: isGuest,
                fullName: fullName,
                phone: phone,
                profileImageUrl: profileImageUrl,
                wallet: wallet,
              ),
              SizedBox(height: 18.h),
              if (isGuest)
                _GuestActionsCard(
                  onLogin: () {
                    ref.read(authRepositoryProvider).signOut();
                    context.go(AppRoutes.login);
                  },
                  onBackHome: () {
                    ref.read(authRepositoryProvider).signOut();
                    context.go(AppRoutes.home);
                  },
                )
              else ...[
                _buildQuickStats(wallet),
                SizedBox(height: 18.h),
                _SectionCard(
                  title: 'إدارة الحساب',
                  subtitle:
                      'كل ما تحتاجه لتحديث بياناتك، متابعة الأمان، والوصول السريع إلى المحفظة.',
                  children: [
                    _ActionTile(
                      title: 'ملفي الشخصي',
                      subtitle: 'تعديل معلوماتك الأساسية وصورتك',
                      icon: Icons.person_outline_rounded,
                      accent: KadmatColors.brandSecondary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      title: 'أمان الحساب',
                      subtitle: 'تغيير كلمة المرور ومتابعة مزايا الأمان',
                      icon: Icons.security_outlined,
                      accent: KadmatColors.stateSuccess,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AccountSecurityScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      title: 'المحفظة',
                      subtitle: _walletSubtitle(walletAsync),
                      icon: Icons.account_balance_wallet_outlined,
                      accent: KadmatColors.stateInfo,
                      onTap: () => context.push(AppRoutes.customerWallet),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                _SectionCard(
                  title: 'تفضيلاتك',
                  subtitle:
                      'اختصر الوصول للخدمات التي تحتاجها باستمرار وابقَ قريبًا من طلباتك المفضلة.',
                  children: [
                    _ActionTile(
                      title: 'الخدمات المفضلة',
                      subtitle: 'عرض الخدمات المحفوظة لديك',
                      icon: Icons.favorite_border_rounded,
                      accent: KadmatColors.stateError,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoriteServicesScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      title: 'تسجيل الخروج',
                      subtitle: 'الخروج الآمن من حسابك الحالي',
                      icon: Icons.logout_rounded,
                      accent: KadmatColors.stateError,
                      onTap: () {
                        ref.read(authRepositoryProvider).signOut();
                        context.go(AppRoutes.login);
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    WidgetRef ref, {
    required bool isGuest,
    required String? fullName,
    required String? phone,
    required String? profileImageUrl,
    required Wallet? wallet,
  }) {
    final displayName = isGuest
        ? 'زائر'
        : (fullName == null || fullName.isEmpty ? 'مستخدم Kadmat' : fullName);
    final subtitle = isGuest
        ? 'سجّل دخولك للوصول إلى الطلبات، الرسائل، والمحفظة من مكان واحد.'
        : phone != null && phone.isNotEmpty
        ? 'رقم الهاتف: $phone'
        : 'حسابك جاهز لإدارة الطلبات والخدمات بسهولة.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF19323C), Color(0xFF0E2028)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatar(name: displayName, imageUrl: profileImageUrl),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.fz,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13.fz,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isGuest)
                IconButton.filledTonal(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ),
            ],
          ),
          if (!isGuest) ...[
            SizedBox(height: 18.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 20.s,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رصيد المحفظة',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.fz,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          wallet == null
                              ? 'جاري تحميل الرصيد...'
                              : '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.fz,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.customerWallet),
                    child: const Text('فتح المحفظة'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(Wallet? wallet) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'المحفظة',
            value: wallet == null ? 'قيد التحميل' : 'جاهزة للاستخدام',
            icon: Icons.payments_outlined,
            accent: KadmatColors.stateInfo,
          ),
        ),
        SizedBox(width: 10.w),
        const Expanded(
          child: _StatCard(
            label: 'جاهزية الحساب',
            value: 'مفعل',
            icon: Icons.verified_outlined,
            accent: KadmatColors.stateSuccess,
          ),
        ),
      ],
    );
  }

  String _walletSubtitle(AsyncValue<dynamic>? walletAsync) {
    if (walletAsync == null) {
      return 'افتح المحفظة لمعرفة الرصيد';
    }

    return walletAsync.when(
      data: (_) => 'عرض الرصيد، السجل، وحالة المحفظة من شاشة واحدة',
      loading: () => 'جاري تحميل الرصيد...',
      error: (_, _) => 'تعذر تحميل الرصيد الآن',
    );
  }
}

class _GuestActionsCard extends StatelessWidget {
  const _GuestActionsCard({required this.onLogin, required this.onBackHome});

  final VoidCallback onLogin;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'ابدأ حسابك',
      subtitle:
          'افتح حسابك للوصول إلى الطلبات، الرسائل، الإشعارات، وحالة المحفظة من واجهة واحدة.',
      children: [
        _ActionTile(
          title: 'تسجيل الدخول / إنشاء حساب',
          subtitle: 'الدخول الكامل إلى خدمات Kadmat',
          icon: Icons.login_rounded,
          accent: KadmatColors.brandSecondary,
          onTap: onLogin,
        ),
        _ActionTile(
          title: 'العودة للشاشة الرئيسية',
          subtitle: 'الرجوع إلى صفحة الترحيب',
          icon: Icons.home_outlined,
          accent: KadmatColors.stateWarning,
          onTap: onBackHome,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6.h),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(icon, color: accent, size: 21.s),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: KadmatColors.lightTextSecondary,
                  size: 24.s,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return CircleAvatar(
      radius: 34.r,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: !hasImage
          ? Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.fz,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: accent, size: 18.s),
          ),
          SizedBox(height: 12.h),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 4.h),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
