import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/navigation/app_routes.dart';
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
    final subtitleColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    final primaryColor = Theme.of(context).primaryColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0.w),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  width: 96.w,
                  height: 96.w,
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
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.engineering,
                      size: 48.s,
                      color: primaryColor,
                    ),
                  ),
                ),
                SizedBox(height: 32.h),

                // Title & Subtitle
                const Text(
                  'مرحباً بعودتك!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  'سجّل الدخول إلى حساب الفني الخاص بك لإدارة خدماتك وعملائك.',
                  style: TextStyle(
                    fontSize: 16.fz,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
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

                // Forgot Password Link
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
                const SizedBox(height: 24),

                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      state.error.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                KadmatPrimaryButton(
                  label: 'تسجيل الدخول',
                  onPressed: _submit,
                  isLoading: state.isLoading,
                ),
                SizedBox(height: 24.h),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ليس لديك حساب؟',
                      style: TextStyle(color: subtitleColor),
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
                SizedBox(height: 16.h),
                // Guest Mode Button (Development)
                TextButton(
                  onPressed: () => context.push(AppRoutes.technicianHome),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text(
                    'الدخول كزائر (للتطوير) 🔧',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
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
}
