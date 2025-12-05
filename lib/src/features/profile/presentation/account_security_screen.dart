import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

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
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildSecurityOption(
              context,
              title: 'تغيير كلمة المرور',
              subtitle: 'قم بتحديث كلمة المرور الخاصة بك بشكل دوري',
              icon: Icons.lock_outline,
              onTap: () {
                // TODO: Show change password dialog or navigate
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم تفعيل هذه الميزة قريباً')),
                );
              },
            ),
            SizedBox(height: 16.h),
            _buildSecurityOption(
              context,
              title: 'المصادقة الثنائية (2FA)',
              subtitle: 'تأمين حسابك برقم جوال إضافي',
              icon: Icons.security,
              onTap: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم تفعيل هذه الميزة قريباً')),
                );
              },
            ),
             SizedBox(height: 16.h),
            _buildSecurityOption(
              context,
              title: 'الأجهزة المتصلة',
              subtitle: 'إدارة الأجهزة التي سجلت الدخول منها',
              icon: Icons.devices,
              onTap: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم تفعيل هذه الميزة قريباً')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.all(12.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      leading: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: Colors.green),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
