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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? KadmatColors.darkBackground
        : KadmatColors.lightBackground;
    final textColor = isDarkMode
        ? KadmatColors.darkTextPrimary
        : KadmatColors.lightTextPrimary;
    final subtitleColor = isDarkMode
        ? KadmatColors.darkTextSecondary
        : KadmatColors.lightTextSecondary;
    const primaryColor = KadmatColors.brandPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 24.h),
                // Header Icon
                Container(
                  width: 96.w,
                  height: 96.w,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? KadmatColors.darkBorder
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode
                          ? KadmatColors.darkBorder
                          : Colors.white,
                      width: 4.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.build, size: 48.s, color: primaryColor),
                  ),
                ),
                SizedBox(height: 24.h),
                // Title
                Text(
                  'انضم إلينا كفني محترف',
                  style: TextStyle(
                    fontSize: 28.fz,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                // Subtitle
                Text(
                  'وسّع نطاق عملك، تواصل مع عملاء جدد، وزد دخلك. كن جزءاً من شبكتنا الموثوقة من الخبراء.',
                  style: TextStyle(
                    fontSize: 16.fz,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48.h),
                // Steps
                _buildStepCard(
                  context,
                  icon: Icons.person_add,
                  title: '1. إنشاء حسابك',
                  description: 'أدخل بياناتك الأساسية للبدء.',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                SizedBox(height: 16.h),
                _buildStepCard(
                  context,
                  icon: Icons.category,
                  title: '2. حدد تخصصك',
                  description: 'اختر مجالات خبرتك (سباكة، كهرباء، نجارة...).',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                SizedBox(height: 16.h),
                _buildStepCard(
                  context,
                  icon: Icons.verified_user,
                  title: '3. التحقق من الهوية',
                  description: 'قم بتحميل مستنداتك لبناء الثقة مع العملاء.',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                SizedBox(height: 48.h),
                // Buttons
                KadmatPrimaryButton(
                  label: 'ابدأ التسجيل',
                  icon: Icons.app_registration_rounded,
                  onPressed: () => context.push(AppRoutes.technicianRegister),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                SizedBox(height: 12.h),
                KadmatSecondaryButton(
                  label: 'لدي حساب بالفعل؟ تسجيل الدخول',
                  icon: Icons.login_rounded,
                  onPressed: () => context.push(AppRoutes.technicianLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return KadmatCard(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 24.s),
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
                    color: isDarkMode
                        ? KadmatColors.darkTextPrimary
                        : KadmatColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: isDarkMode
                        ? KadmatColors.darkTextSecondary
                        : KadmatColors.lightTextSecondary,
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
