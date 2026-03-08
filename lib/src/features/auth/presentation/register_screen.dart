import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
import 'widgets/customer_auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim(),
          fullName: _nameController.text.trim(),
        );

    if (success && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('إنشاء حساب جديد'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 620.w),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CustomerAuthHero(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'ابدأ حسابك بدون تعقيد',
                      subtitle:
                          'املأ بياناتك الأساسية مرة واحدة، وبعدها تنتقل مباشرة إلى الصفحة الرئيسية لطلب أول خدمة.',
                    ),
                    SizedBox(height: 16.h),
                    const CustomerAuthInfoCard(
                      icon: Icons.track_changes_outlined,
                      title: 'الخطوة الأهم الآن',
                      description:
                          'أدخل الاسم، الجوال، البريد، وكلمة مرور واضحة. لا تحتاج أي إعدادات إضافية قبل البدء باستخدام التطبيق.',
                    ),
                    SizedBox(height: 16.h),
                    CustomerAuthSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'بيانات الحساب',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'هذه البيانات تكفي لإنشاء حساب العميل وبدء استخدام التطبيق فورًا.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(height: 18.h),
                          KadmatTextField(
                            controller: _nameController,
                            label: 'الاسم الكامل',
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال الاسم';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          KadmatTextField(
                            controller: _emailController,
                            label: 'البريد الإلكتروني',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال البريد الإلكتروني';
                              }
                              if (!value.contains('@')) {
                                return 'البريد الإلكتروني غير صحيح';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          KadmatTextField(
                            controller: _phoneController,
                            label: 'رقم الجوال',
                            hint: '05xxxxxxxx',
                            prefixIcon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال رقم الجوال';
                              }
                              if (value.length < 10) {
                                return 'رقم الجوال غير صحيح';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          KadmatTextField(
                            controller: _passwordController,
                            label: 'كلمة المرور',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال كلمة المرور';
                              }
                              if (value.length < 6) {
                                return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          KadmatTextField(
                            controller: _confirmPasswordController,
                            label: 'تأكيد كلمة المرور',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء تأكيد كلمة المرور';
                              }
                              if (value != _passwordController.text) {
                                return 'كلمات المرور غير متطابقة';
                              }
                              return null;
                            },
                          ),
                          if (state.hasError) ...[
                            SizedBox(height: 16.h),
                            CustomerAuthInfoCard(
                              icon: Icons.error_outline,
                              title: 'تعذر إنشاء الحساب',
                              description: ErrorHandler.getMessage(state.error),
                              tint: const Color(0xFFFBE7EA),
                              iconColor: const Color(0xFFB23A48),
                            ),
                          ],
                          SizedBox(height: 16.h),
                          KadmatPrimaryButton(
                            label: 'إنشاء حساب',
                            onPressed: _submit,
                            isLoading: state.isLoading,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    CustomerAuthSurface(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('لديك حساب بالفعل؟'),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.login),
                            child: const Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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
