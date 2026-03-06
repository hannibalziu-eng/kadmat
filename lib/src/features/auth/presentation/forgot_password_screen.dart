import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSent = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور'), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: _isSent
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 80.s,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'تم إرسال الرابط',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'تم إرسال رابط إعادة تعيين كلمة المرور إلى ${_emailController.text}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 14.fz,
                    ),
                  ),
                  SizedBox(height: 32.h),
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
                    SizedBox(height: 24.h),
                    Text(
                      'استعادة كلمة المرور',
                      style: TextStyle(
                        fontSize: 24.fz,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لاستعادة كلمة المرور',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 14.fz,
                      ),
                    ),
                    SizedBox(height: 32.h),
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
                    SizedBox(height: 24.h),
                    KadmatPrimaryButton(
                      label: 'إرسال الرابط',
                      icon: Icons.send_rounded,
                      onPressed: _submit,
                      isLoading: _isLoading,
                    ),
                    SizedBox(height: 12.h),
                    KadmatSecondaryButton(
                      label: 'الرجوع',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
