import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
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
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
            requiredUserType: 'customer',
          );
      if (success && mounted) {
        context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0.w),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أهلاً بك',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                KadmatTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  prefixIcon: Icons.email,
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
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال كلمة المرور';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (state.hasError)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0.h),
                    child: Text(
                      state.error.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      context.push(AppRoutes.forgotPassword);
                    },
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
                SizedBox(height: 24.h),
                KadmatPrimaryButton(
                  label: 'دخول',
                  onPressed: _submit,
                  isLoading: state.isLoading,
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: const Text('أو'),
                    ),
                    const Expanded(child: Divider()),
                  ],
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
                const SizedBox(height: 16),
                KadmatSecondaryButton(
                  label: 'تسجيل الدخول الاجتماعي',
                  icon: Icons.alternate_email,
                  onPressed: state.isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const OAuthLoginScreen(),
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
