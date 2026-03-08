import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/design/kadmat_tokens.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';

class TechnicianLoginScreen extends ConsumerStatefulWidget {
  const TechnicianLoginScreen({super.key});

  @override
  ConsumerState<TechnicianLoginScreen> createState() =>
      _TechnicianLoginScreenState();
}

class _TechnicianLoginScreenState extends ConsumerState<TechnicianLoginScreen> {
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
            requiredUserType: 'technician',
          );

      if (success && mounted) {
        context.go(AppRoutes.technicianHome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28.r),
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
                            width: 54.w,
                            height: 54.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                            child: Icon(
                              Icons.engineering_rounded,
                              color: Colors.white,
                              size: 24.s,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'مساحة الفني',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12.fz,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'سجّل دخولك وابدأ استقبال الطلبات',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.fz,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'استخدم حساب الفني للوصول إلى الطلبات القريبة، العروض، المحفظة، وسجل الأعمال من مكان واحد واضح.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 12.8.fz,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Container(
                      padding: EdgeInsets.all(20.w),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KadmatTextField(
                            controller: _emailController,
                            label: 'البريد الإلكتروني أو رقم الهاتف',
                            hint: 'ادخل بريدك الإلكتروني أو رقم هاتفك',
                            prefixIcon: Icons.alternate_email,
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
                            hint: 'ادخل كلمة المرور',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال كلمة المرور';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () =>
                                  context.push(AppRoutes.forgotPassword),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (state.hasError) ...[
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: KadmatColors.stateError.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: KadmatColors.stateError.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: Text(
                                ErrorHandler.getMessage(state.error),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: KadmatColors.stateError,
                                  fontSize: 12.5.fz,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 16.h),
                          KadmatPrimaryButton(
                            label: 'تسجيل الدخول',
                            onPressed: _submit,
                            isLoading: state.isLoading,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ليس لديك حساب؟',
                          style: TextStyle(
                            color: KadmatColors.lightTextSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.technicianRegister),
                          child: const Text(
                            'أنشئ حساباً جديداً',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (kDebugMode) ...[
                      SizedBox(height: 10.h),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.technicianHome),
                          style: TextButton.styleFrom(
                            foregroundColor: KadmatColors.lightTextSecondary,
                          ),
                          child: const Text('الدخول كزائر للتطوير'),
                        ),
                      ),
                    ],
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
