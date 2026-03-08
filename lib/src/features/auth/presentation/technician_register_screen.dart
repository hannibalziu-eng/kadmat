import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/photo_upload_provider.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
import '../data/auth_repository.dart';

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

  // Document Upload State
  final List<XFile> _selectedDocuments = [];
  bool _isUploading = false;
  String _uploadStatus = '';
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocuments() async {
    try {
      final uploadService = ref.read(photoUploadServiceProvider);
      final photos = await uploadService.pickPhotos(
        source: ImageSource.gallery,
        maxPhotos: 5 - _selectedDocuments.length,
      );

      if (photos.isNotEmpty) {
        setState(() {
          _selectedDocuments.addAll(photos);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
      }
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _selectedDocuments.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_isUploading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDocuments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء رفع صورة الهوية أو شهادات الخبرة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _submitError = null;
      _isUploading = true;
      _uploadStatus = 'جاري رفع المستندات...';
    });

    try {
      // 1. Upload Documents
      final uploadService = ref.read(photoUploadServiceProvider);
      List<String> documentUrls = [];

      if (_selectedDocuments.isNotEmpty) {
        documentUrls = await uploadService.uploadMultiplePhotos(
          _selectedDocuments,
          'technician_documents',
          onProgress: (current, total) {
            if (!mounted) return;
            setState(() {
              _uploadStatus = 'جاري رفع المستندات ($current / $total)...';
            });
          },
        );
      }

      // 2. Register
      if (!mounted) return;
      setState(() => _uploadStatus = 'جاري إنشاء الحساب...');

      await ref
          .read(authRepositoryProvider)
          .register(
            email: _emailController.text,
            password: _passwordController.text,
            phone: _phoneController.text,
            fullName: _nameController.text,
            userType: 'technician',
            serviceId: _selectedService,
            documentUrls: documentUrls,
          );

      if (mounted) {
        context.go(AppRoutes.technicianHome);
      }
    } catch (e) {
      final message = ErrorHandler.getMessage(e);
      if (mounted) {
        setState(() {
          _submitError = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

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

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'التسجيل الاجتماعي للفنيين غير متاح حالياً، لأن إنشاء الحساب يتطلب اختيار التخصص ورفع المستندات قبل التفعيل.',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: subtitleColor.withValues(alpha: 0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('أو', style: TextStyle(color: subtitleColor)),
                    ),
                    Expanded(
                      child: Divider(
                        color: subtitleColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                KadmatTextField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  hint: 'أدخل اسمك الكامل',
                  prefixIcon: Icons.person_outline,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'الرجاء إدخال الاسم' : null,
                ),
                const SizedBox(height: 16),

                KadmatTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'example@mail.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'الرجاء إدخال البريد الإلكتروني'
                      : null,
                ),
                const SizedBox(height: 16),

                KadmatTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hint: '+966 5xxxxxxxx',
                  prefixIcon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'الرجاء إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 16),

                KadmatTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  hint: '********',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'الرجاء إدخال كلمة المرور'
                      : null,
                ),
                const SizedBox(height: 16),

                KadmatTextField(
                  controller: _confirmPasswordController,
                  label: 'تأكيد كلمة المرور',
                  hint: '********',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'كلمات المرور غير متطابقة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Specialty
                _buildLabel('مجال التخصص'),
                Consumer(
                  builder: (context, ref, child) {
                    final servicesAsync = ref.watch(activeServicesProvider);

                    return servicesAsync.when(
                      data: (services) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedService,
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
                      error: (err, stack) => Text(
                        ErrorHandler.getMessage(err),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Documents Upload Area
                _buildLabel('المستندات المطلوبة (الهوية، الشهادات)'),

                // File List
                if (_selectedDocuments.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedDocuments.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _selectedDocuments[index];
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: kIsWeb
                                  ? Image.network(
                                      file.path,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.insert_drive_file,
                                                ),
                                              ),
                                    )
                                  : Image.file(
                                      File(file.path),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.insert_drive_file,
                                                ),
                                              ),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeDocument(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // Upload Button
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
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: InkWell(
                    onTap: _isUploading ? null : _pickDocuments,
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
                                text: 'انقر لرفع المستندات',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDocuments.length} ملفات تم اختيارها',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isUploading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    _uploadStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 32),

                if (_submitError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _submitError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Submit Button
                KadmatPrimaryButton(
                  label: 'إنشاء الحساب',
                  onPressed: _isUploading ? null : _submit,
                  isLoading: _isUploading,
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
