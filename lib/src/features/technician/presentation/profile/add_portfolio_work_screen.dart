import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/technician_repository.dart';
import '../../../../core/providers/photo_upload_provider.dart';
import '../../../../core/utils/error_handler.dart';

class AddPortfolioWorkScreen extends ConsumerStatefulWidget {
  const AddPortfolioWorkScreen({super.key});

  @override
  ConsumerState<AddPortfolioWorkScreen> createState() =>
      _AddPortfolioWorkScreenState();
}

class _AddPortfolioWorkScreenState
    extends ConsumerState<AddPortfolioWorkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  XFile? _selectedImage;
  Uint8List? _imageBytes; // Cached bytes for web preview
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final photoService = ref.read(photoUploadServiceProvider);
    try {
      final photos = await photoService.pickPhotos(
        source: ImageSource.gallery,
        maxPhotos: 1,
      );
      if (photos.isNotEmpty) {
        final xfile = photos.first;
        // Cache bytes for web preview
        final bytes = await xfile.readAsBytes();
        setState(() {
          _selectedImage = xfile;
          _imageBytes = bytes;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إضافة صورة للعمل')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final photoService = ref.read(photoUploadServiceProvider);
      final techRepo = ref.read(technicianRepositoryProvider);

      // 1. Upload Photo
      final imageUrl = await photoService.uploadPhoto(
        _selectedImage!,
        'portfolio',
      );

      // 2. Save Portfolio Item
      await techRepo.addPortfolioWork({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'completion_date': _dateController.text,
        'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إضافة العمل بنجاح')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عمل جديد'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image Upload
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey[400]!),
                    image: _selectedImage != null && _imageBytes != null
                        ? DecorationImage(
                            image: kIsWeb
                                ? MemoryImage(_imageBytes!)
                                : FileImage(File(_selectedImage!.path))
                                      as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48.s,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'إضافة صورة للعمل',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              SizedBox(height: 24.h),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان العمل',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'تاريخ الإنجاز',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    _dateController.text =
                        "${date.year}-${date.month}-${date.day}";
                  }
                },
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف العمل',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 32.h),

              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('نشر العمل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
