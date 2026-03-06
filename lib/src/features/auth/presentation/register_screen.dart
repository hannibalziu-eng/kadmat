import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';

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
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authControllerProvider.notifier)
          .register(
            email: _emailController.text,
            password: _passwordController.text,
            phone: _phoneController.text,
            fullName: _nameController.text,
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
      appBar: AppBar(title: const Text('إنشاء حساب جديد'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0.w),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'مرحباً بك!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'قم بإنشاء حسابك للبدء',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                  label: 'إنشاء حساب',
                  onPressed: _submit,
                  isLoading: state.isLoading,
                ),
                const SizedBox(height: 16),
                Row(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
