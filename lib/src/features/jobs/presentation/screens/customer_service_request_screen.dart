import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/providers/photo_upload_provider.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/kadmat_components.dart';
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

  Service? get _selectedService {
    final selectedId = _selectedServiceId;
    if (selectedId == null) return null;
    for (final service in _services) {
      if (service.id == selectedId) return service;
    }
    return null;
  }

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
    final selectedService = _selectedService;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('طلب خدمة جديدة')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
            children: [
              _RequestHeroCard(selectedService: selectedService),
              SizedBox(height: 18.h),
              _SectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KadmatSectionHeader(
                      title: '1. اختر الخدمة',
                      subtitle:
                          'ابدأ بتحديد نوع الخدمة المطلوبة حتى نعرض طلبك للفنيين المناسبين.',
                    ),
                    SizedBox(height: 14.h),
                    if (_isLoadingServices)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(18.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: _services
                            .map(
                              (service) => _ServiceOptionChip(
                                label: service.nameAr ?? service.name,
                                isSelected: _selectedServiceId == service.id,
                                onTap: () => setState(
                                  () => _selectedServiceId = service.id,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (_services.isEmpty && !_isLoadingServices) ...[
                      SizedBox(height: 10.h),
                      Text(
                        'لا توجد خدمات متاحة الآن.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: KadmatColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KadmatSectionHeader(
                      title: '2. حدّد الموقع',
                      subtitle:
                          'اكتب عنوانًا واضحًا وتأكد من تحديث موقعك الحالي قبل إرسال الطلب.',
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText:
                            'مثال: بن عاشور، شارع النصر، قرب صيدلية الربيع',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'مطلوب'
                          : null,
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: KadmatColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.w,
                                decoration: BoxDecoration(
                                  color:
                                      (_lat != null && _lng != null
                                              ? KadmatColors.stateSuccess
                                              : KadmatColors.brandAccent)
                                          .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  _lat != null && _lng != null
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.my_location_rounded,
                                  color: _lat != null && _lng != null
                                      ? KadmatColors.stateSuccess
                                      : KadmatColors.brandSecondary,
                                  size: 18.s,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  _locationHint ??
                                      'سنستخدم موقعك الحالي بدل أي موقع افتراضي أو ثابت.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(height: 1.55),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),
                          KadmatSecondaryButton(
                            label: _isLocating
                                ? 'جاري تحديد الموقع...'
                                : 'تحديث موقعي الحالي',
                            icon: Icons.gps_fixed_rounded,
                            onPressed: _isLocating ? null : _resolveLocation,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KadmatSectionHeader(
                      title: '3. اشرح المشكلة',
                      subtitle:
                          'كلما كان الوصف أوضح، كانت العروض أدق والرد أسرع.',
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText:
                            'اشرح المشكلة، متى بدأت، وهل هناك تفاصيل مهمة يجب أن يعرفها الفني...',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'مطلوب'
                          : null,
                    ),
                    SizedBox(height: 16.h),
                    const KadmatSectionHeader(
                      title: 'صور توضيحية',
                      subtitle:
                          'اختيارية، لكنها تساعد الفني على فهم الحالة قبل الوصول.',
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      height: 108.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length + 1,
                        separatorBuilder: (_, __) => SizedBox(width: 10.w),
                        itemBuilder: (context, index) {
                          if (index == _photos.length) {
                            return GestureDetector(
                              onTap: _pickPhoto,
                              child: Container(
                                width: 108.h,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: KadmatColors.lightBorder,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: KadmatColors.brandSecondary,
                                      size: 26.s,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'إضافة صورة',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18.r),
                                child: kIsWeb
                                    ? Image.network(
                                        _photos[index].path,
                                        width: 108.h,
                                        height: 108.h,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_photos[index].path),
                                        width: 108.h,
                                        height: 108.h,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _photos.removeAt(index)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: KadmatColors.stateError,
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
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: KadmatColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جاهز لإرسال الطلب؟',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'سنعرض طلبك للفنيين القريبين بمجرد الإرسال، ثم يمكنك مراجعة العروض واختيار الأنسب.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KadmatColors.lightTextSecondary,
                        height: 1.55,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    KadmatPrimaryButton(
                      label: 'إرسال الطلب',
                      icon: Icons.send_rounded,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submitRequest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestHeroCard extends StatelessWidget {
  const _RequestHeroCard({required this.selectedService});

  final Service? selectedService;

  @override
  Widget build(BuildContext context) {
    final serviceName = selectedService?.nameAr ?? selectedService?.name;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17313B), Color(0xFF0E2128)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.handyman_outlined,
              size: 22.s,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'أرسل طلبك بخطوات واضحة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            serviceName == null
                ? 'اختر الخدمة، حدّد موقعك، ثم أضف وصفًا واضحًا حتى تصل العروض المناسبة بسرعة.'
                : 'الخدمة المحددة الآن: $serviceName. أكمل التفاصيل وسنعرض طلبك مباشرة على الفنيين المناسبين.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.5.fz,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ServiceOptionChip extends StatelessWidget {
  const _ServiceOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected
                ? KadmatColors.brandSecondary
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected
                  ? KadmatColors.brandSecondary
                  : KadmatColors.lightBorder,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSelected ? Colors.white : KadmatColors.lightTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
