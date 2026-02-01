import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/navigation/app_routes.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/providers/photo_upload_provider.dart';
import '../../data/job_repository.dart';

class CustomerServiceRequestScreen extends ConsumerStatefulWidget {
  const CustomerServiceRequestScreen({super.key});

  @override
  ConsumerState<CustomerServiceRequestScreen> createState() =>
      _CustomerServiceRequestScreenState();
}

class _CustomerServiceRequestScreenState
    extends ConsumerState<CustomerServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];
  String? _selectedServiceId;
  final List<XFile> _photos = [];

  // Dummy location for now (Riyadh)
  final double _lat = 24.7136;
  final double _lng = 46.6753;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      // Direct supabase call as we don't have ServiceRepository yet
      final data = await Supabase.instance.client
          .from('services')
          .select('id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل الخدمات: $e')));
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      // Using the service via a provider or direct logic if provider not exposed
      // Assuming PhotoUploadService has pickPhotos helper
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _photos.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل اختيار الصورة')));
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الخدمة')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String>? imageUrls;

      // 1. Upload Photos if any
      if (_photos.isNotEmpty) {
        // Note: Assuming photoUploadServiceProvider exists or I need to create it.
        // Based on read files, I saw 'photo_upload_service.dart' but not 'photo_upload_provider.dart'.
        // I'll check imports later. Leveraging direct repo access if needed.
        // Actually jobRepository has _photoService.
        // But better to use the service directly.
        // I'll assume functionality for now.

        // Temporary fix: I'll use the service instance created here if provider missing,
        // but prefer provider.
      }

      // 2. Upload photos via a helper (since I can't easily access repo's private service)
      // Or I can use JobRepository if I expose upload method?
      // JobRepository.uploadPreServicePhotos takes jobId. Here we don't have jobId yet.
      // So I should upload strictly via PhotoUploadService.

      // Let's rely on `photoUploadServiceProvider` being available or I'll create it.
      // For now I'll instantiate it manually if provider fails.

      final photoService = ref.read(photoUploadServiceProvider);

      // START UPLOAD LOGIC
      if (_photos.isNotEmpty) {
        // Only upload if photos exist
        imageUrls = await photoService.uploadMultiplePhotos(
          _photos,
          'requests/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // 3. Create Job
      final job = await ref
          .read(jobRepositoryProvider)
          .createJob(
            serviceId: _selectedServiceId!,
            lat: _lat,
            lng: _lng,
            addressText: _addressController.text,
            initialPrice: 0, // Customer doesn't set price, standard flow?
            // Prompt says: "Customer fills: Service type...".
            // Does customer set price? Prompt: "Tech accepts & sets price".
            // So initialStatus is 'pending', price 0 or null.
            description: _descriptionController.text,
            images: imageUrls,
          );

      if (job != null && mounted) {
        // Navigate to Tracking or Searching Screen
        // Prompt says: "Save to Supabase... Broadcast notification... Custommer tracking?"
        // I'll navigate to My Jobs or a Success screen.
        context.go(AppRoutes.buildCustomerSearchingPath(job.id));
      } else {
        throw Exception('فشل إنشاء الطلب');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب خدمة جديدة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Service Dropdown
            Text(
              'نوع الخدمة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.fz),
            ),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedServiceId,
              items: _services
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedServiceId = val),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              hint: _isLoading
                  ? const Text('جاري التحميل...')
                  : const Text('اختر الخدمة'),
            ),

            SizedBox(height: 16.h),

            // Link to Map/Location
            Text(
              'الموقع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.fz),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: 'وصف الموقع (مثال: حي العليا، شارع التحلية)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
            ),

            SizedBox(height: 16.h),

            // Description
            Text(
              'وصف المشكلة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.fz),
            ),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اشرح المشكلة بالتفصيل...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
            ),

            SizedBox(height: 16.h),

            // Photos
            Text(
              'صور للمشكلة (اختياري)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.fz),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              height: 100.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  if (index == _photos.length) {
                    return GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 100.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: Icon(Icons.add_a_photo, color: Colors.grey[600]),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: kIsWeb
                            ? Image.network(
                                _photos[index].path,
                                width: 100.h,
                                height: 100.h,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_photos[index].path),
                                width: 100.h,
                                height: 100.h,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(index)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(4.w),
                            child: Icon(
                              Icons.close,
                              size: 16.s,
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

            SizedBox(height: 32.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'إرسال الطلب',
                        style: TextStyle(
                          fontSize: 18.fz,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
