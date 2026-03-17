import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
import 'widgets/technician_auth_widgets.dart';

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

    return TechnicianAuthScaffold(
      topActionLabel: 'إنشاء حساب',
      onTopAction: () => context.push(AppRoutes.technicianRegister),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TechnicianAuthHero(
              icon: Icons.engineering_rounded,
              title: 'ادخل وابدأ استقبال الطلبات',
              subtitle:
                  'استخدم حساب الفني للوصول إلى الطلبات القريبة، التسعير، التنفيذ، والمحفظة من تجربة تشغيلية واضحة.',
            ),
            SizedBox(height: 16.h),
            const TechnicianAuthInfoCard(
              icon: Icons.track_changes_outlined,
              title: 'الخطوة الأهم الآن',
              description:
                  'أدخل بريدك أو هاتفك وكلمة المرور فقط. إذا نسيت كلمة المرور استخدم الرابط المباشر أسفل النموذج بدل تكرار المحاولات.',
            ),
            SizedBox(height: 16.h),
            TechnicianAuthSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بيانات الدخول',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'بعد تسجيل الدخول ستنتقل مباشرة إلى مساحة العمل الخاصة بالفني.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 18.h),
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
                      onPressed: () => context.push(AppRoutes.forgotPassword),
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
                    TechnicianAuthInfoCard(
                      icon: Icons.error_outline,
                      title: 'تعذر تسجيل الدخول',
                      description: ErrorHandler.getMessage(state.error),
                      tint: const Color(0xFFFBE7EA),
                      iconColor: const Color(0xFFB23A48),
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
            SizedBox(height: 16.h),
            TechnicianAuthSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      Text(
                        'ليس لديك حساب؟',
                        style: TextStyle(
                          color: KadmatColors.lightTextSecondary,
                          fontSize: 13.fz,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push(AppRoutes.technicianRegister),
                        child: const Text(
                          'أنشئ حسابًا جديدًا',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (kDebugMode) ...[
                    SizedBox(height: 6.h),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.technicianHome),
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
          ],
        ),
      ),
    );
  }
}
