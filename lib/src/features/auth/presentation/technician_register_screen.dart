import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/social_auth_button.dart';
import 'auth_controller.dart';

class TechnicianRegisterScreen extends ConsumerStatefulWidget {
  const TechnicianRegisterScreen({super.key});

  @override
  ConsumerState<TechnicianRegisterScreen> createState() =>
      _TechnicianRegisterScreenState();
}

class _TechnicianRegisterScreenState
    extends ConsumerState<TechnicianRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedService;
  bool _isSocialLogin = false;

  void _simulateSocialLogin() {
    setState(() {
      _isSocialLogin = true;
      _nameController.text = 'أحمد محمد (من فيسبوك)';
      _emailController.text = 'ahmed.fb@example.com';
      // Password fields are not needed
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم جلب البيانات من فيسبوك. يرجى إكمال باقي المعلومات.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

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
            userType: 'technician',
            serviceId: _selectedService,
          );

      if (success && mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    // Using the theme colors defined in AppTheme
    final subtitleColor =
        Theme.of(context).inputDecorationTheme.labelStyle?.color ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(''), // Empty title as per design which has H1 in body
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إنشاء حساب فني جديد',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'انضم إلى شبكتنا من الفنيين المحترفين.',
                  style: TextStyle(fontSize: 16, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Social Auth Section
                Row(
                  children: [
                    Expanded(
                      child: SocialAuthButton(
                        text: 'جوجل',
                        icon: Icons.g_mobiledata,
                        iconColor: Colors.red,
                        onPressed: _simulateSocialLogin,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SocialAuthButton(
                        text: 'فيسبوك',
                        icon: Icons.facebook,
                        iconColor: Colors.blue,
                        onPressed: _simulateSocialLogin,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Divider(color: subtitleColor.withOpacity(0.3)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('أو', style: TextStyle(color: subtitleColor)),
                    ),
                    Expanded(
                      child: Divider(color: subtitleColor.withOpacity(0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Full Name
                _buildLabel('الاسم الكامل'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'أدخل اسمك الكامل',
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'الرجاء إدخال الاسم' : null,
                ),
                const SizedBox(height: 16),

                // Email
                _buildLabel('البريد الإلكتروني'),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'example@mail.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isSocialLogin, // Read-only if social login
                  validator: (value) => value?.isEmpty ?? true
                      ? 'الرجاء إدخال البريد الإلكتروني'
                      : null,
                ),
                const SizedBox(height: 16),

                // Phone
                _buildLabel('رقم الهاتف'),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(hintText: '+966 5xxxxxxxx'),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'الرجاء إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 16),

                if (!_isSocialLogin) ...[
                  // Password
                  _buildLabel('كلمة المرور'),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(hintText: '********'),
                    obscureText: true,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'الرجاء إدخال كلمة المرور'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  _buildLabel('تأكيد كلمة المرور'),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(hintText: '********'),
                    obscureText: true,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'كلمات المرور غير متطابقة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Specialty
                _buildLabel('مجال التخصص'),
                // Specialty
                _buildLabel('مجال التخصص'),
                Consumer(
                  builder: (context, ref, child) {
                    final servicesAsync = ref.watch(activeServicesProvider);

                    return servicesAsync.when(
                      data: (services) {
                        return DropdownButtonFormField<String>(
                          value: _selectedService,
                          decoration: const InputDecoration(
                            hintText: 'اختر تخصصك',
                          ),
                          items: services.map((service) {
                            final name =
                                service['name_ar'] as String? ??
                                service['name'] as String;
                            return DropdownMenuItem<String>(
                              value: service['id'] as String,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedService = newValue;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'الرجاء اختيار التخصص' : null,
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Text('خطأ في تحميل التخصصات: $err'),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Documents Upload Area
                _buildLabel('المستندات المطلوبة'),
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          Theme.of(
                            context,
                          ).inputDecorationTheme.border?.borderSide.color ??
                          Colors.grey,
                      style: BorderStyle
                          .solid, // Flutter doesn't support dashed natively easily without CustomPainter, using solid for now to match theme
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Handle file upload
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, size: 40, color: subtitleColor),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: subtitleColor,
                              fontFamily: 'Cairo',
                            ),
                            children: const [
                              TextSpan(
                                text: 'انقر للتحميل',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' أو اسحب وأفلت'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ملفات الهوية والخبرة',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                  height: 50,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : _submit,
                    child: state.isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF101d22),
                          )
                        : Text(
                            _isSocialLogin ? 'إكمال التسجيل' : 'إنشاء الحساب',
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
    );
  }
}
