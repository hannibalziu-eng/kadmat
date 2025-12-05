import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import 'edit_profile_screen.dart';
import 'account_security_screen.dart';
import 'favorite_services_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final isGuest = authRepo.currentUser == 'guest';

    final userProfile = authRepo.userProfile;
    final fullName = userProfile?['full_name'] ?? 'مستخدم';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'حسابي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (!isGuest)
            IconButton(
              icon: Icon(Icons.logout, size: 24.s, color: Colors.red),
              onPressed: () {
                ref.read(authRepositoryProvider).signOut();
                context.go('/login');
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20.h),
            // Profile Header
            Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 4.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10.r,
                            offset: Offset(0, 5.h),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50.r,
                        backgroundImage: isGuest
                            ? null
                            : const NetworkImage(
                                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
                              ),
                        backgroundColor: Colors.grey[200],
                        child: isGuest
                            ? Icon(Icons.person, size: 50.s, color: Colors.grey)
                            : null,
                      ),
                    ),
                    if (!isGuest)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: const BoxDecoration(
                            color: Color(0xFF13b6ec),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16.s,
                          ),
                        ),
                      ),
                  ],
                ).animate().scale(duration: 400.ms),
                SizedBox(height: 12.h),
                Text(
                  isGuest ? 'زائر' : fullName,
                  style: TextStyle(
                    fontSize: 20.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().slideY(begin: 0.5),
                SizedBox(height: 4.h),
                Text(
                  isGuest
                      ? 'سجل دخولك للاستفادة من كامل الميزات'
                      : 'مرحباً بعودتك!',
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ).animate().fadeIn().slideY(begin: 0.5, delay: 100.ms),
              ],
            ),

            SizedBox(height: 32.h),

            // Settings Options
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  if (isGuest) ...[
                    _buildProfileOption(
                      context,
                      title: 'تسجيل الدخول / إنشاء حساب',
                      subtitle: 'الوصول الكامل لجميع الخدمات',
                      icon: Icons.login,
                      iconColor: const Color(0xFF13b6ec),
                      iconBgColor: const Color(0xFF13b6ec).withOpacity(0.1),
                      onTap: () {
                        ref.read(authRepositoryProvider).signOut();
                        context.go('/login');
                      },
                    ),
                    SizedBox(height: 16.h),
                    _buildProfileOption(
                      context,
                      title: 'العودة للشاشة الرئيسية',
                      subtitle: 'الرجوع لشاشة الترحيب',
                      icon: Icons.home_outlined,
                      iconColor: Colors.orange,
                      iconBgColor: Colors.orange.withOpacity(0.1),
                      onTap: () {
                         ref.read(authRepositoryProvider).signOut();
                         context.go('/'); // Assuming '/' is welcome or splash
                      },
                    ),
                  ] else ...[
                    _buildProfileOption(
                      context,
                      title: 'ملفي الشخصي',
                      subtitle: 'تعديل معلوماتك الشخصية',
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF13b6ec),
                      iconBgColor: const Color(0xFF13b6ec).withOpacity(0.1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EditProfileScreen()),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildProfileOption(
                      context,
                      title: 'أمان الحساب',
                      subtitle: 'تغيير كلمة المرور وتفعيل 2FA',
                      icon: Icons.security,
                      iconColor: Colors.green,
                      iconBgColor: Colors.green.withOpacity(0.1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AccountSecurityScreen()),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildProfileOption(
                      context,
                      title: 'المحفظة',
                      subtitle: 'رصيدك الحالي: 350.00 ر.س',
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: Colors.blue,
                      iconBgColor: Colors.blue.withOpacity(0.1),
                      onTap: () => context.push('/customer-wallet'),
                    ),
                    SizedBox(height: 16.h),
                    _buildProfileOption(
                      context,
                      title: 'الخدمات المفضلة',
                      subtitle: 'عرض الخدمات المحفوظة لديك',
                      icon: Icons.favorite_border,
                      iconColor: Colors.red,
                      iconBgColor: Colors.red.withOpacity(0.1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const FavoriteServicesScreen()),
                      ),
                    ),
                  ],
                ]
                    .animate(interval: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.2, end: 0),
              ),
            ),
            SizedBox(height: 80.h), // Bottom nav padding
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: iconColor, size: 24.s),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.fz,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24.s),
          ],
        ),
      ),
    );
  }
}
