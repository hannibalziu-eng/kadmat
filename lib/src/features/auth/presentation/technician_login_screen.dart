import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        context.go('/technician/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final subtitleColor =
        Theme.of(context).inputDecorationTheme.labelStyle?.color ?? Colors.grey;
    final primaryColor = Theme.of(context).primaryColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  width: 96,
                  height: 96,
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
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.engineering,
                      size: 48,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title & Subtitle
                const Text(
                  'مرحباً بعودتك!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'سجّل الدخول إلى حساب الفني الخاص بك لإدارة خدماتك وعملائك.',
                  style: TextStyle(
                    fontSize: 16,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email/Phone Field
                _buildLabel('البريد الإلكتروني أو رقم الهاتف'),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'ادخل بريدك الإلكتروني أو رقم هاتفك',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال البريد الإلكتروني';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                _buildLabel('كلمة المرور'),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    hintText: 'ادخل كلمة المرور',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
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
                    onPressed: () => context.push('/forgot-password'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : _submit,
                    child: state.isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF101d22),
                          )
                        : const Text('تسجيل الدخول'),
                  ),
                ),

                const SizedBox(height: 24),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ليس لديك حساب؟',
                      style: TextStyle(color: subtitleColor),
                    ),
                    TextButton(
                      onPressed: () => context.push('/technician/register'),
                      child: const Text(
                        'أنشئ حساباً جديداً',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Guest Mode Button (Development)
                TextButton(
                  onPressed: () => context.push('/technician/home'),
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

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                Theme.of(context).inputDecorationTheme.labelStyle?.color ??
                Colors.grey,
          ),
        ),
      ),
    );
  }
}
