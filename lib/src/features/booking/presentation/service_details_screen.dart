import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import '../../jobs/presentation/job_controller.dart';

class ServiceDetailsScreen extends ConsumerStatefulWidget {
  final String serviceId;
  final String serviceName;

  const ServiceDetailsScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });

  @override
  ConsumerState<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends ConsumerState<ServiceDetailsScreen> {
  String? _selectedQuickOption;
  final _descriptionController = TextEditingController();
  bool _locationConfirmed = false;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      // Handle error
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  List<Map<String, dynamic>> _getQuickOptions() {
    // Different options based on service type
    if (widget.serviceName.contains('سباك') ||
        widget.serviceName.contains('سباكة')) {
      return [
        {'icon': Icons.water_drop, 'label': 'تسريب صنبور'},
        {'icon': Icons.plumbing, 'label': 'انسداد بالوعة'},
        {'icon': Icons.shower, 'label': 'مشكلة في الدش'},
        {'icon': Icons.more_horiz, 'label': 'أخرى'},
      ];
    } else if (widget.serviceName.contains('كهرباء') ||
        widget.serviceName.contains('كهربائ')) {
      return [
        {'icon': Icons.lightbulb_outline, 'label': 'مصباح لا يعمل'},
        {'icon': Icons.power_off, 'label': 'انقطاع كهرباء'},
        {'icon': Icons.electrical_services, 'label': 'مشكلة في المفاتيح'},
        {'icon': Icons.more_horiz, 'label': 'أخرى'},
      ];
    } else if (widget.serviceName.contains('نجار') ||
        widget.serviceName.contains('نجارة')) {
      return [
        {'icon': Icons.door_sliding, 'label': 'إصلاح باب'},
        {'icon': Icons.weekend, 'label': 'تركيب أثاث'},
        {'icon': Icons.carpenter, 'label': 'صيانة خشب'},
        {'icon': Icons.more_horiz, 'label': 'أخرى'},
      ];
    } else {
      return [
        {'icon': Icons.build, 'label': 'صيانة عامة'},
        {'icon': Icons.cleaning_services, 'label': 'تنظيف'},
        {'icon': Icons.handyman, 'label': 'إصلاح'},
        {'icon': Icons.more_horiz, 'label': 'أخرى'},
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickOptions = _getQuickOptions();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          widget.serviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Request Section
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب سريع',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'اختر نوع المشكلة الأكثر شيوعًا لطلب الخدمة فورًا.',
                    style: TextStyle(
                      fontSize: 14.fz,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: quickOptions.map((option) {
                      final isSelected =
                          _selectedQuickOption == option['label'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedQuickOption = option['label'];
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1)
                                : Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withOpacity(0.1),
                              width: 2.w,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                option['icon'],
                                size: 32.s,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(context).iconTheme.color,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                option['label'],
                                style: TextStyle(
                                  fontSize: 13.fz,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Problem Description Section
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل المشكلة (اختياري)',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'كلما زادت التفاصيل، كانت الخدمة أفضل.',
                    style: TextStyle(
                      fontSize: 14.fz,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'صف المشكلة هنا...',
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).inputDecorationTheme.fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'إضافة صور أو فيديو',
                    style: TextStyle(
                      fontSize: 16.fz,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 100.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length + 1,
                      separatorBuilder: (context, index) =>
                          SizedBox(width: 12.w),
                      itemBuilder: (context, index) {
                        if (index == _selectedImages.length) {
                          return _buildAddImageButton();
                        }
                        return _buildImageItem(index);
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Customer Location Confirmation Section
            InkWell(
              onTap: () {
                setState(() {
                  _locationConfirmed = !_locationConfirmed;
                });
              },
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: _locationConfirmed
                      ? Colors.green.withOpacity(0.1)
                      : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: _locationConfirmed
                        ? Colors.green
                        : Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 2.w,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        color: _locationConfirmed
                            ? Colors.green
                            : Theme.of(context).scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _locationConfirmed
                            ? Icons.check_circle
                            : Icons.location_on,
                        color: _locationConfirmed
                            ? Colors.white
                            : Theme.of(context).iconTheme.color,
                        size: 32.s,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locationConfirmed ? 'تم تأكيد الموقع ✓' : 'موقعي',
                            style: TextStyle(
                              fontSize: 18.fz,
                              fontWeight: FontWeight.bold,
                              color: _locationConfirmed
                                  ? Colors.green
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _locationConfirmed
                                ? 'سيصل الفني إلى موقعك الحالي'
                                : 'اضغط لتأكيد موقعك الحالي',
                            style: TextStyle(
                              fontSize: 14.fz,
                              color: _locationConfirmed
                                  ? Colors.green
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 80.h), // Bottom button padding
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestService,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13b6ec),
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.r),
              ),
            ),
            child: _isLoading 
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'طلب الخدمة الآن',
                    style: TextStyle(
                      fontSize: 16.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestService() async {
    // Validate location
    if (!_locationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تأكيد موقعك أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isLoading) return; // Prevent double tap
    
    setState(() => _isLoading = true);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يرجى السماح بالوصول للموقع لإتمام الطلب'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoading = false);
          // Show dialog to open settings
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('إذن الموقع مطلوب'),
              content: const Text('يرجى تفعيل إذن الموقع من الإعدادات'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('فتح الإعدادات'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Create the job
      final job = await ref.read(jobControllerProvider.notifier).createJob(
        serviceId: widget.serviceId,
        lat: position.latitude,
        lng: position.longitude,
        description: _selectedQuickOption != null 
            ? '$_selectedQuickOption\n${_descriptionController.text}'
            : _descriptionController.text,
        addressText: 'موقعي الحالي',
        initialPrice: 0, // Price will be set by technician
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (job != null && mounted) {
        // Navigate to searching screen
        context.push(
          '/searching-for-technician',
          extra: {
            'jobId': job.id,
            'serviceName': widget.serviceName,
            'lat': position.latitude,
            'lng': position.longitude,
          },
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إنشاء الطلب، يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageItem(int index) {
    return Stack(
      children: [
        Container(
          width: 100.w,
          height: 100.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            color: Theme.of(context).cardTheme.color,
            image: DecorationImage(
              image: FileImage(File(_selectedImages[index].path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () => _removeImage(index),
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16.s, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        width: 100.w,
        height: 100.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 2.w,
            style: BorderStyle.solid,
          ),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 32.s,
              color: Theme.of(context).iconTheme.color,
            ),
            SizedBox(height: 4.h),
            Text(
              'إضافة',
              style: TextStyle(
                fontSize: 12.fz,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
