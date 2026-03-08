import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';
import '../../../core/design/kadmat_tokens.dart';
import '../../../core/utils/error_handler.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _emailController = TextEditingController();
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(authRepositoryProvider).userProfile;
    _nameController = TextEditingController(
      text: userProfile?['full_name'] ?? '',
    );
    _phoneController = TextEditingController(text: userProfile?['phone'] ?? '');
    _emailController.text = userProfile?['email'] ?? '';
    _avatarUrl =
        userProfile?['avatar_url']?.toString() ??
        userProfile?['profile_image_url']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            fullName: _nameController.text,
            phone: _phoneController.text,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات بنجاح')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 920.w),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      title: 'حدّث بياناتك الأساسية فقط',
                      subtitle:
                          'الاسم ورقم الجوال هما أكثر ما يحتاجه التطبيق ليعرض حسابك بشكل صحيح في الصفحات الرئيسية والإشعارات.',
                    ),
                    SizedBox(height: 16.h),
                    const _InfoCard(
                      icon: Icons.track_changes_outlined,
                      title: 'الخطوة الأهم الآن',
                      description:
                          'راجع الاسم ورقم الجوال فقط. البريد الإلكتروني ظاهر هنا للمرجع ولا يحتاج تعديل من هذه الشاشة.',
                    ),
                    SizedBox(height: 16.h),
                    _Surface(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42.r,
                            backgroundColor: KadmatColors.brandAccent,
                            backgroundImage:
                                _avatarUrl != null && _avatarUrl!.isNotEmpty
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null || _avatarUrl!.isEmpty
                                ? Text(
                                    (_nameController.text.trim().isNotEmpty
                                            ? _nameController.text
                                                  .trim()
                                                  .characters
                                                  .first
                                            : '؟')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 24.fz,
                                      fontWeight: FontWeight.w800,
                                      color: KadmatColors.brandSecondary,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            'المعلومات الأساسية',
                            style: TextStyle(
                              fontSize: 17.fz,
                              fontWeight: FontWeight.w800,
                              color: KadmatColors.lightTextPrimary,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'تغيير هذه الحقول ينعكس مباشرة على ملفك وحسابك داخل التطبيق.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5.fz,
                              height: 1.55,
                              color: KadmatColors.lightTextSecondary,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          TextFormField(
                            controller: _nameController,
                            validator: (val) => val == null || val.isEmpty
                                ? 'الاسم مطلوب'
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الكامل',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (val) => val == null || val.isEmpty
                                ? 'رقم الجوال مطلوب'
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            enabled: false,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('حفظ التغييرات'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
            child: Icon(Icons.edit_outlined, color: Colors.white, size: 22.s),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
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
