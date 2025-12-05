import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TechnicianLandingScreen extends StatelessWidget {
  const TechnicianLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF101d22)
        : const Color(0xFFf6f8f8);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1e293b);
    final subtitleColor = isDarkMode
        ? const Color(0xFF92bbc9)
        : const Color(0xFF64748b);
    const primaryColor = Color(0xFF13b6ec);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // Header Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF233f48)
                        : const Color(0xFFe2e8f0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF334155)
                          : Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.build, size: 48, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'انضم إلينا كفني محترف',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'وسّع نطاق عملك، تواصل مع عملاء جدد، وزد دخلك. كن جزءاً من شبكتنا الموثوقة من الخبراء.',
                  style: TextStyle(
                    fontSize: 16,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Steps
                _buildStepCard(
                  context,
                  icon: Icons.person_add,
                  title: '1. إنشاء حسابك',
                  description: 'أدخل بياناتك الأساسية للبدء.',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildStepCard(
                  context,
                  icon: Icons.category,
                  title: '2. حدد تخصصك',
                  description: 'اختر مجالات خبرتك (سباكة، كهرباء، نجارة...).',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildStepCard(
                  context,
                  icon: Icons.verified_user,
                  title: '3. التحقق من الهوية',
                  description: 'قم بتحميل مستنداتك لبناء الثقة مع العملاء.',
                  isDarkMode: isDarkMode,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 48),
                // Buttons
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.push('/technician/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black, // Slate-900 equivalent
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'ابدأ التسجيل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () => context.push('/technician/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'لدي حساب بالفعل؟ تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1a2b32) : const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1e293b),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? const Color(0xFF92bbc9)
                        : const Color(0xFF64748b),
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
