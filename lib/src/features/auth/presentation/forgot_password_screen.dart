import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
import 'widgets/customer_auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email: _emailController.text.trim());

    if (success && mounted) {
      setState(() => _isSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('نسيت كلمة المرور'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560.w),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: _isSent
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CustomerAuthHero(
                          icon: Icons.mark_email_read_outlined,
                          title: 'تحقق من بريدك الإلكتروني',
                          subtitle:
                              'إذا كان البريد صحيحًا ومربوطًا بالحساب، ستصلك رسالة تحتوي على خطوات إعادة تعيين كلمة المرور.',
                        ),
                        SizedBox(height: 16.h),
                        CustomerAuthInfoCard(
                          icon: Icons.info_outline,
                          title: 'تم إرسال الطلب',
                          description:
                              'راجع صندوق الوارد ورسائل البريد غير الهام في ${_emailController.text}. إذا لم تصل الرسالة خلال دقائق، أعد المحاولة أو تأكد من صحة البريد.',
                        ),
                        SizedBox(height: 16.h),
                        KadmatPrimaryButton(
                          label: 'العودة لتسجيل الدخول',
                          icon: Icons.login_rounded,
                          onPressed: () => context.go(AppRoutes.login),
                        ),
                      ],
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CustomerAuthHero(
                            icon: Icons.lock_reset_outlined,
                            title: 'استعد الوصول إلى حسابك',
                            subtitle:
                                'أدخل بريدك الإلكتروني فقط، وسنرسل لك رابط إعادة التعيين إذا كان الحساب موجودًا ومهيأً لذلك.',
                          ),
                          SizedBox(height: 16.h),
                          const CustomerAuthInfoCard(
                            icon: Icons.track_changes_outlined,
                            title: 'الخطوة الأهم الآن',
                            description:
                                'اكتب البريد الإلكتروني المرتبط بالحساب ثم أرسل الطلب. لا تحتاج إلى أي بيانات أخرى في هذه المرحلة.',
                          ),
                          SizedBox(height: 16.h),
                          CustomerAuthSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'إرسال رابط الاستعادة',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'سيصل الرابط إلى البريد الإلكتروني إذا كانت إعدادات إعادة التعيين مهيأة لهذا الحساب.',
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
                                    if (!value.contains('@')) {
                                      return 'البريد الإلكتروني غير صحيح';
                                    }
                                    return null;
                                  },
                                ),
                                if (state.hasError) ...[
                                  SizedBox(height: 16.h),
                                  CustomerAuthInfoCard(
                                    icon: Icons.error_outline,
                                    title: 'تعذر إرسال رابط الاستعادة',
                                    description: ErrorHandler.getMessage(
                                      state.error,
                                    ),
                                    tint: const Color(0xFFFBE7EA),
                                    iconColor: const Color(0xFFB23A48),
                                  ),
                                ],
                                SizedBox(height: 16.h),
                                KadmatPrimaryButton(
                                  label: 'إرسال الرابط',
                                  icon: Icons.send_rounded,
                                  onPressed: _submit,
                                  isLoading: state.isLoading,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                          KadmatSecondaryButton(
                            label: 'الرجوع',
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => context.pop(),
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
