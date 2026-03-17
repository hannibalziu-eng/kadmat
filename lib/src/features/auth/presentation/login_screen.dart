import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
import 'widgets/customer_auth_widgets.dart';
import 'widgets/oauth_login_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          requiredUserType: 'customer',
        );
    if (success && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return CustomerAuthScaffold(
      topActionLabel: 'إنشاء حساب',
      onTopAction: () => context.push(AppRoutes.register),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CustomerAuthHero(
              icon: Icons.login_rounded,
              title: 'ارجع لحسابك بسرعة',
              subtitle:
                  'ادخل إلى طلباتك ورسائلك وحسابك من مكان واحد، بدون خطوات إضافية أو شاشات مشتتة.',
            ),
            SizedBox(height: 16.h),
            const CustomerAuthInfoCard(
              icon: Icons.track_changes_outlined,
              title: 'الخطوة الأهم الآن',
              description:
                  'أدخل البريد وكلمة المرور فقط. إذا نسيت كلمة المرور استخدم الرابط المباشر أسفل النموذج بدل تكرار المحاولات.',
            ),
            SizedBox(height: 16.h),
            CustomerAuthSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بيانات الدخول',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'بعد تسجيل الدخول ستنتقل مباشرة إلى الصفحة الرئيسية للعميل.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 18.h),
                  KadmatTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال البريد الإلكتروني';
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
                      return null;
                    },
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ),
                  if (state.hasError) ...[
                    SizedBox(height: 8.h),
                    CustomerAuthInfoCard(
                      icon: Icons.error_outline,
                      title: 'تعذر تسجيل الدخول',
                      description: ErrorHandler.getMessage(state.error),
                      tint: const Color(0xFFFBE7EA),
                      iconColor: const Color(0xFFB23A48),
                    ),
                  ],
                  SizedBox(height: 16.h),
                  KadmatPrimaryButton(
                    label: 'دخول',
                    onPressed: _submit,
                    isLoading: state.isLoading,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            CustomerAuthSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'خيارات إضافية',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'استخدمها فقط إذا كنت تريد تجربة التصفح السريع أو تسجيل الدخول عبر مزود خارجي.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16.h),
                  KadmatSecondaryButton(
                    label: 'دخول كزائر',
                    icon: Icons.person_outline,
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            final success = await ref
                                .read(authControllerProvider.notifier)
                                .signInAsGuest();
                            if (!context.mounted || !success) return;
                            context.go(AppRoutes.home);
                          },
                  ),
                  SizedBox(height: 12.h),
                  KadmatSecondaryButton(
                    label: 'تسجيل الدخول الاجتماعي',
                    icon: Icons.alternate_email,
                    onPressed: state.isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const OAuthLoginScreen(),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
