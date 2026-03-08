import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/providers/photo_upload_provider.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../home/data/service_repository.dart';
import '../../../home/domain/service.dart';
import '../../data/job_repository.dart';

class CustomerServiceRequestScreen extends ConsumerStatefulWidget {
  final String? initialServiceId;

  const CustomerServiceRequestScreen({super.key, this.initialServiceId});

  @override
  ConsumerState<CustomerServiceRequestScreen> createState() =>
      _CustomerServiceRequestScreenState();
}

class _CustomerServiceRequestScreenState
    extends ConsumerState<CustomerServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingServices = false;
  bool _isLocating = false;
  List<Service> _services = [];
  String? _selectedServiceId;
  final List<XFile> _photos = [];
  double? _lat;
  double? _lng;
  String? _locationHint;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _resolveLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    try {
      final services = await ref.read(serviceRepositoryProvider).getServices();
      if (!mounted) return;
      setState(() {
        _services = services.where((service) => service.isActive).toList();
        if (widget.initialServiceId != null &&
            _services.any((service) => service.id == widget.initialServiceId)) {
          _selectedServiceId = widget.initialServiceId;
        }
        _isLoadingServices = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingServices = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    }
  }

  Future<void> _resolveLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('خدمة الموقع غير مفعلة على الجهاز');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('يجب السماح بالوصول إلى الموقع لتحديد مكان الخدمة');
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      final position =
          lastKnown ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationHint =
            'تم تحديد الموقع الحالي (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
        _isLocating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationHint = ErrorHandler.getMessage(error);
      });
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _photos.add(image));
      }
    } catch (_) {
      if (!mounted) return;
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
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تحديد موقعك الحالي قبل إرسال الطلب')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String>? imageUrls;
      if (_photos.isNotEmpty) {
        final photoService = ref.read(photoUploadServiceProvider);
        imageUrls = await photoService.uploadMultiplePhotos(
          _photos,
          'requests/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final job = await ref
          .read(jobRepositoryProvider)
          .createJob(
            serviceId: _selectedServiceId!,
            lat: _lat!,
            lng: _lng!,
            addressText: _addressController.text.trim(),
            initialPrice: 0,
            description: _descriptionController.text.trim(),
            images: imageUrls,
          );

      if (!mounted) return;
      if (job == null) {
        throw Exception('فشل إنشاء الطلب');
      }

      context.go(AppRoutes.buildCustomerSearchingPath(job.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
            Text(
              'نوع الخدمة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.fz),
            ),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedServiceId,
              items: _services
                  .map(
                    (service) => DropdownMenuItem(
                      value: service.id,
                      child: Text(service.nameAr ?? service.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedServiceId = value),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              hint: _isLoadingServices
                  ? const Text('جاري تحميل الخدمات...')
                  : const Text('اختر الخدمة'),
            ),
            SizedBox(height: 16.h),
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
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lat != null && _lng != null
                            ? Icons.check_circle_outline
                            : Icons.my_location,
                        color: _lat != null && _lng != null
                            ? Colors.green
                            : Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationHint ??
                              'يتم استخدام موقعك الحالي بدلاً من أي موقع افتراضي.',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  OutlinedButton.icon(
                    onPressed: _isLocating ? null : _resolveLocation,
                    icon: const Icon(Icons.gps_fixed),
                    label: Text(
                      _isLocating
                          ? 'جاري تحديد الموقع...'
                          : 'تحديث موقعي الحالي',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
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
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            SizedBox(height: 16.h),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isSubmitting
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
