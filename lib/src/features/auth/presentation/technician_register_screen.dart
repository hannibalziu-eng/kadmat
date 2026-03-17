import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/photo_upload_provider.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/kadmat_components.dart';
import 'auth_controller.dart';
import '../data/auth_repository.dart';
import 'widgets/technician_auth_widgets.dart';

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

    return TechnicianAuthScaffold(
      topActionLabel: 'تسجيل الدخول',
      onTopAction: () => context.go(AppRoutes.technicianLogin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TechnicianAuthHero(
              icon: Icons.badge_outlined,
              title: 'أنشئ حساب الفني بخطوات واضحة',
              subtitle:
                  'أكمل بياناتك الأساسية، اختر تخصصك، وارفع المستندات المطلوبة حتى يصبح حسابك جاهزًا للمراجعة والتفعيل.',
            ),
            SizedBox(height: 16.h),
            TechnicianAuthInfoCard(
              icon: Icons.info_outline,
              title: 'قبل المتابعة',
              description:
                  'لا يوجد تسجيل اجتماعي للفنيين في هذه المرحلة لأن الحساب يحتاج تخصصًا ومستندات قبل التفعيل.',
            ),
            SizedBox(height: 16.h),
            TechnicianAuthSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'البيانات الأساسية',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'هذه المعلومات تكفي لإنشاء حساب الفني وبدء مرحلة المراجعة بشكل صحيح.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 18.h),
                  KadmatTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    hint: 'أدخل اسمك الكامل',
                    prefixIcon: Icons.person_outline,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'الرجاء إدخال الاسم' : null,
                  ),
                  SizedBox(height: 16.h),
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
                  SizedBox(height: 16.h),
                  KadmatTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: '+966 5xxxxxxxx',
                    prefixIcon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'الرجاء إدخال رقم الهاتف'
                        : null,
                  ),
                  SizedBox(height: 16.h),
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
                  SizedBox(height: 16.h),
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
                  SizedBox(height: 18.h),
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
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (err, stack) => Text(
                          ErrorHandler.getMessage(err),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            TechnicianAuthSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'المستندات المطلوبة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'ارفع صورة الهوية أو شهادات الخبرة. هذه الخطوة مطلوبة قبل مراجعة الحساب وتفعيله.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16.h),
                  if (_selectedDocuments.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      height: 100.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedDocuments.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(width: 8.w),
                        itemBuilder: (context, index) {
                          final file = _selectedDocuments[index];
                          return Stack(
                            children: [
                              Container(
                                width: 100.w,
                                height: 100.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: kIsWeb
                                    ? Image.network(
                                        file.path,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => const Center(
                                          child: Icon(Icons.insert_drive_file),
                                        ),
                                      )
                                    : Image.file(
                                        File(file.path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => const Center(
                                          child: Icon(Icons.insert_drive_file),
                                        ),
                                      ),
                              ),
                              Positioned(
                                top: 4.h,
                                right: 4.w,
                                child: GestureDetector(
                                  onTap: () => _removeDocument(index),
                                  child: Container(
                                    padding: EdgeInsets.all(4.w),
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
                  Container(
                    height: 148.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Theme.of(context)
                                .inputDecorationTheme
                                .border
                                ?.borderSide
                                .color ??
                            Colors.grey,
                      ),
                    ),
                    child: InkWell(
                      onTap: _isUploading ? null : _pickDocuments,
                      borderRadius: BorderRadius.circular(16.r),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file_rounded,
                              size: 40.s,
                              color: subtitleColor,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'انقر لرفع المستندات',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 13.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '${_selectedDocuments.length} ملفات تم اختيارها',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.fz,
                                color: subtitleColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isUploading) ...[
                    SizedBox(height: 16.h),
                    const LinearProgressIndicator(),
                    SizedBox(height: 8.h),
                    Text(
                      _uploadStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.fz,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                  if (_submitError != null) ...[
                    SizedBox(height: 16.h),
                    TechnicianAuthInfoCard(
                      icon: Icons.error_outline,
                      title: 'تعذر إنشاء الحساب',
                      description: _submitError!,
                      tint: const Color(0xFFFBE7EA),
                      iconColor: const Color(0xFFB23A48),
                    ),
                  ],
                  SizedBox(height: 18.h),
                  KadmatPrimaryButton(
                    label: 'إنشاء الحساب',
                    onPressed: _isUploading ? null : _submit,
                    isLoading: _isUploading,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            TechnicianAuthSurface(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6.w,
                runSpacing: 4.h,
                children: [
                  Text(
                    'لديك حساب بالفعل؟',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13.fz,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.technicianLogin),
                    child: const Text('سجّل الدخول'),
                  ),
                ],
              ),
            ),
          ],
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
