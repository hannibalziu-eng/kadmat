import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/providers/photo_upload_provider.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/location_error_message.dart';
import '../../../../core/widgets/kadmat_components.dart';
import '../../../home/data/service_repository.dart';
import '../../../home/domain/service.dart';
import '../../../home/domain/service_catalog_item.dart';
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
  final _detailsController = TextEditingController();
  final _expectedPriceController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingServices = false;
  bool _isLoadingCatalogItems = false;
  bool _isLocating = false;
  bool _useCurrentLocation = false;
  bool _manualLocationExpanded = false;
  bool _manualLocationSelected = false;

  List<Service> _services = [];
  List<ServiceCatalogItem> _catalogItems = const [];
  String? _selectedServiceId;
  String? _catalogLoadError;
  final List<XFile> _photos = [];
  final Map<String, int> _selectedCatalogQuantities = {};
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

  bool get _hasResolvedLocation => _lat != null && _lng != null;
  bool get _hasAnyChosenLocation =>
      _hasResolvedLocation && (_useCurrentLocation || _manualLocationSelected);
  bool get _hasLocationError =>
      !_hasAnyChosenLocation && (_locationHint?.trim().isNotEmpty ?? false);
  bool get _requiresSecureLocationContext {
    if (!kIsWeb) return false;
    final base = Uri.base;
    final host = base.host.toLowerCase();
    final isLocalhost =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    return base.scheme != 'https' && !isLocalhost;
  }

  bool get _selectedServiceSupportsCatalog {
    final service = _selectedService;
    if (service == null) return false;
    return service.pricingModeDefault == 'catalog_fixed' ||
        service.isCatalogEnabled;
  }

  int get _selectedCatalogItemCount => _selectedCatalogQuantities.values.fold(
    0,
    (sum, quantity) => sum + quantity,
  );

  double get _catalogSubtotal {
    var subtotal = 0.0;
    for (final item in _catalogItems) {
      final quantity = _selectedCatalogQuantities[item.id] ?? 0;
      if (quantity <= 0) continue;
      subtotal += item.price * quantity;
    }
    return double.parse(subtotal.toStringAsFixed(2));
  }

  String get _resolvedAddressText {
    if (_hasResolvedLocation && _manualLocationSelected) {
      return 'موقع محدد يدويًا (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})';
    }
    if (_hasResolvedLocation) {
      return 'موقع العميل الحالي (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})';
    }
    return 'موقع غير محدد';
  }

  LatLng get _manualMapCenter {
    if (_lat != null && _lng != null) {
      return LatLng(_lat!, _lng!);
    }
    return const LatLng(32.8872, 13.1913);
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _expectedPriceController.dispose();
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
      await _syncCatalogStateForSelectedService();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingServices = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    }
  }

  Future<void> _syncCatalogStateForSelectedService() async {
    final service = _selectedService;
    if (service == null || !_selectedServiceSupportsCatalog) {
      if (!mounted) return;
      setState(() {
        _isLoadingCatalogItems = false;
        _catalogItems = const [];
        _catalogLoadError = null;
        _selectedCatalogQuantities.clear();
      });
      return;
    }

    setState(() {
      _isLoadingCatalogItems = true;
      _catalogItems = const [];
      _catalogLoadError = null;
      _selectedCatalogQuantities.clear();
    });

    try {
      final items = await ref
          .read(serviceRepositoryProvider)
          .getServiceCatalogItems(service.id);
      if (!mounted) return;
      final activeItems = items.where((item) => item.isActive).toList();
      setState(() {
        _catalogItems = activeItems;
        _isLoadingCatalogItems = false;
        if (activeItems.isEmpty) {
          _catalogLoadError = 'لا توجد عناصر ثابتة متاحة لهذه الخدمة الآن.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingCatalogItems = false;
        _catalogItems = const [];
        _catalogLoadError = ErrorHandler.getMessage(error);
      });
    }
  }

  Future<void> _handleServiceSelected(String serviceId) async {
    if (_selectedServiceId == serviceId) return;
    setState(() {
      _selectedServiceId = serviceId;
    });
    await _syncCatalogStateForSelectedService();
  }

  void _setCatalogItemQuantity(ServiceCatalogItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _selectedCatalogQuantities.remove(item.id);
      } else {
        _selectedCatalogQuantities[item.id] = quantity;
      }
    });
  }

  Future<void> _toggleCurrentLocation() async {
    if (_useCurrentLocation) {
      setState(() {
        _useCurrentLocation = false;
        _lat = null;
        _lng = null;
        _manualLocationSelected = false;
        _locationHint =
            'تم إيقاف استخدام الموقع الحالي. يمكنك التفعيل مجددًا أو اختيار الموقع يدويًا.';
      });
      return;
    }

    setState(() {
      _useCurrentLocation = true;
      _manualLocationSelected = false;
    });
    await _resolveLocation();
  }

  void _toggleManualLocationPicker() {
    setState(() {
      _manualLocationExpanded = !_manualLocationExpanded;
      if (_manualLocationExpanded) {
        _useCurrentLocation = false;
        if (!_manualLocationSelected) {
          _locationHint =
              'اضغط على الخريطة لتثبيت مكان الوصول يدويًا إذا لم يعمل الموقع التلقائي.';
        }
      }
    });
  }

  void _selectManualLocation(LatLng point) {
    setState(() {
      _lat = point.latitude;
      _lng = point.longitude;
      _manualLocationExpanded = true;
      _manualLocationSelected = true;
      _useCurrentLocation = false;
      _locationHint =
          'تم تحديد مكان الوصول يدويًا. سيصل الفني إلى هذه النقطة على الخريطة.';
    });
  }

  Future<void> _resolveLocation() async {
    setState(() => _isLocating = true);
    try {
      if (_requiresSecureLocationContext) {
        throw Exception('secure context required for geolocation');
      }

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

      Position? lastKnown;
      if (!kIsWeb) {
        try {
          lastKnown = await Geolocator.getLastKnownPosition();
        } catch (_) {
          lastKnown = null;
        }
      }

      final position = lastKnown ?? await _getFreshPosition();
      if (!mounted) return;

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationHint =
            'تم تحديد موقعك الحالي بدقة جيدة. سيصل الفني إلى هذا الموقع ما لم تكتب تعليمات أوضح في العنوان.';
        _useCurrentLocation = true;
        _isLocating = false;
      });
    } catch (error) {
      if (!mounted) return;
      final message = resolveLocationErrorMessage(error);
      setState(() {
        _isLocating = false;
        _useCurrentLocation = false;
        _locationHint = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<Position> _getFreshPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).first.timeout(const Duration(seconds: 10));
    }
  }

  Future<void> _pickPhotos(ImageSource source) async {
    try {
      final uploadService = ref.read(photoUploadServiceProvider);
      final picked = await uploadService.pickPhotos(
        source: source,
        maxPhotos: 5 - _photos.length,
      );
      if (picked.isNotEmpty) {
        setState(() {
          _photos.addAll(picked);
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    }
  }

  Future<void> _showPhotoPickerSheet() async {
    if (_photos.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يمكنك رفع 5 صور كحد أقصى')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: KadmatColors.lightBorder,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                SizedBox(height: 14.h),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('اختيار من المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhotos(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('التقاط صورة من الكاميرا'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhotos(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildDescriptionPayload() {
    return _detailsController.text.trim();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الخدمة')));
      return;
    }
    if (!_hasAnyChosenLocation || _lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدّد مكان الوصول أولًا، تلقائيًا أو يدويًا على الخريطة',
          ),
        ),
      );
      return;
    }
    if (_selectedServiceSupportsCatalog && _selectedCatalogQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر عنصرًا واحدًا على الأقل من عناصر السعر الثابت'),
        ),
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

      final expectedPrice = double.tryParse(
        _expectedPriceController.text.trim(),
      );
      final catalogItemsPayload = _selectedCatalogQuantities.entries
          .map(
            (entry) => {
              'service_catalog_item_id': entry.key,
              'quantity': entry.value,
            },
          )
          .toList();
      final job = await ref
          .read(jobRepositoryProvider)
          .createJob(
            serviceId: _selectedServiceId!,
            lat: _lat!,
            lng: _lng!,
            addressText: _resolvedAddressText,
            initialPrice: _selectedServiceSupportsCatalog
                ? _catalogSubtotal
                : expectedPrice ?? 0,
            description: _buildDescriptionPayload(),
            images: imageUrls,
            pricingMode: _selectedServiceSupportsCatalog
                ? 'catalog_fixed'
                : null,
            catalogItems: _selectedServiceSupportsCatalog
                ? catalogItemsPayload
                : null,
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
    final hasCatalogSection = _selectedServiceSupportsCatalog;
    final locationStep = hasCatalogSection
        ? '3. حدّد مكان الوصول'
        : '2. حدّد مكان الوصول';
    final detailsStep = hasCatalogSection
        ? '4. اشرح المشكلة'
        : '3. اشرح المشكلة';
    final photosStep = hasCatalogSection
        ? '5. أضف صورًا توضيحية'
        : '4. أضف صورًا توضيحية';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('طلب خدمة جديدة')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
            children: [
              _RequestHeroCard(selectedService: selectedService),
              SizedBox(height: 18.h),
              _SectionSurface(
                title: '1. اختر الخدمة',
                subtitle:
                    'اختر الخدمة أولًا حتى نعرض طلبك للفنيين المناسبين فقط.',
                child: _isLoadingServices
                    ? Container(
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
                    : Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: _services
                            .map(
                              (service) => _ServiceOptionChip(
                                label: service.nameAr ?? service.name,
                                isCatalogEnabled: service.isCatalogEnabled,
                                pricingModeDefault: service.pricingModeDefault,
                                isSelected: _selectedServiceId == service.id,
                                onTap: () => _handleServiceSelected(service.id),
                              ),
                            )
                            .toList(),
                      ),
              ),
              if (hasCatalogSection) ...[
                SizedBox(height: 16.h),
                _SectionSurface(
                  title: '2. اختر عناصر الخدمة',
                  subtitle:
                      'هذه الخدمة تعمل بسعر ثابت. اختر العناصر المطلوبة قبل إرسال الطلب.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isLoadingCatalogItems)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        )
                      else if (_catalogLoadError != null)
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7F2),
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(color: const Color(0xFFF0D7C4)),
                          ),
                          child: Text(
                            _catalogLoadError!,
                            style: TextStyle(
                              color: KadmatColors.lightTextPrimary,
                              fontSize: 13.fz,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        )
                      else ...[
                        ..._catalogItems.map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: _CatalogItemTile(
                              item: item,
                              quantity:
                                  _selectedCatalogQuantities[item.id] ?? 0,
                              onChanged: (quantity) =>
                                  _setCatalogItemQuantity(item, quantity),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFD),
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(color: const Color(0xFFD9E6EE)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _CatalogSummaryMetric(
                                  label: 'العناصر المختارة',
                                  value: '$_selectedCatalogItemCount',
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _CatalogSummaryMetric(
                                  label: 'الإجمالي',
                                  value:
                                      '${_catalogSubtotal.toStringAsFixed(2)} د.ل',
                                  highlight: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16.h),
              _SectionSurface(
                title: locationStep,
                subtitle:
                    'اختر موقع الوصول تلقائيًا أو حدده يدويًا على الخريطة.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_requiresSecureLocationContext)
                      const _LocalPreviewLocationNotice()
                    else
                      _AnimatedLocationToggle(
                        isActive: _useCurrentLocation,
                        isLoading: _isLocating,
                        isError: _hasLocationError,
                        hint: _locationHint,
                        onTap: _isLocating ? null : _toggleCurrentLocation,
                      ),
                    SizedBox(height: 12.h),
                    _ManualLocationPickerCard(
                      isExpanded: _manualLocationExpanded,
                      hasSelectedLocation: _manualLocationSelected,
                      hint: _locationHint,
                      center: _manualMapCenter,
                      selectedPoint:
                          _manualLocationSelected && _hasResolvedLocation
                          ? LatLng(_lat!, _lng!)
                          : null,
                      onToggle: _toggleManualLocationPicker,
                      onMapTap: _selectManualLocation,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionSurface(
                title: detailsStep,
                subtitle:
                    'اكتب التفاصيل الأساسية فقط حتى يفهم الفني الحالة بسرعة قبل الوصول.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _detailsController,
                      maxLines: 5,
                      style: TextStyle(
                        color: KadmatColors.lightTextPrimary,
                        fontSize: 14.fz,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                      ),
                      decoration: _requestInputDecoration(
                        context,
                        hintText:
                            'اكتب التفاصيل الأساسية فقط: ما المشكلة، متى بدأت، وأي معلومة مهمة تساعد الفني على الفهم السريع.',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'أدخل تفاصيل الخدمة'
                          : null,
                    ),
                    SizedBox(height: 14.h),
                    TextFormField(
                      controller: _expectedPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: KadmatColors.lightTextPrimary,
                        fontSize: 14.fz,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _requestInputDecoration(
                        context,
                        hintText: 'القيمة المتوقعة للخدمة (اختياري)',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        suffixText: 'د.ل',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return null;
                        final number = double.tryParse(trimmed);
                        if (number == null || number < 0) {
                          return 'أدخل قيمة صحيحة';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionSurface(
                title: photosStep,
                subtitle:
                    'الصور اختيارية لكنها ترفع جودة العروض وتساعد الفني على الاستعداد قبل الوصول.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_photos.isNotEmpty)
                      SizedBox(
                        height: 108.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, __) => SizedBox(width: 10.w),
                          itemBuilder: (context, index) {
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
                                  top: 6.h,
                                  right: 6.w,
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
                    if (_photos.isNotEmpty) SizedBox(height: 12.h),
                    KadmatSecondaryButton(
                      label: _photos.isEmpty
                          ? 'إضافة صور توضيحية'
                          : 'إضافة صور أخرى',
                      icon: Icons.add_a_photo_outlined,
                      onPressed: _showPhotoPickerSheet,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'يمكنك رفع حتى 5 صور. الفيديو غير مفعّل في هذه النسخة.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KadmatColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
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
                      'بعد الإرسال سيظهر الطلب للفنيين المناسبين، ثم يمكنك مراجعة العروض واختيار الأنسب.',
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
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF14314E), Color(0xFF102338)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28.r,
            offset: Offset(0, 18.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              Icons.home_repair_service_rounded,
              size: 24.s,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'صفحة طلب خدمة أوضح وأسهل',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.fz,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            serviceName == null
                ? 'اختر الخدمة، فعّل موقعك الحالي، ثم أضف التفاصيل التي تساعد الفني على فهم الحالة بسرعة.'
                : 'الخدمة المحددة الآن: $serviceName. أكمل التفاصيل وسنعرض طلبك مباشرة على الفنيين المناسبين.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13.2.fz,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KadmatSectionHeader(title: title, subtitle: subtitle),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}

class _AnimatedLocationToggle extends StatelessWidget {
  const _AnimatedLocationToggle({
    required this.isActive,
    required this.isLoading,
    required this.isError,
    required this.hint,
    required this.onTap,
  });

  final bool isActive;
  final bool isLoading;
  final bool isError;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: isActive ? 1 : 0.96),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFEAF9F1)
              : isError
              ? const Color(0xFFFFF4F2)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: isActive
                ? KadmatColors.stateSuccess.withValues(alpha: 0.42)
                : isError
                ? KadmatColors.stateError.withValues(alpha: 0.28)
                : KadmatColors.lightBorder,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: KadmatColors.stateSuccess.withValues(alpha: 0.12),
                blurRadius: 24.r,
                offset: Offset(0, 12.h),
              ),
            if (isError)
              BoxShadow(
                color: KadmatColors.stateError.withValues(alpha: 0.08),
                blurRadius: 18.r,
                offset: Offset(0, 10.h),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22.r),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: isActive
                          ? KadmatColors.stateSuccess.withValues(alpha: 0.18)
                          : isError
                          ? KadmatColors.stateError.withValues(alpha: 0.12)
                          : KadmatColors.brandAccent,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isActive
                                ? Icons.check_circle_rounded
                                : isError
                                ? Icons.location_off_rounded
                                : Icons.my_location_rounded,
                            color: isActive
                                ? KadmatColors.stateSuccess
                                : isError
                                ? KadmatColors.stateError
                                : KadmatColors.brandSecondary,
                            size: 24.s,
                          ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الفني يجي إلى موقعي الحالي',
                          style: TextStyle(
                            color: KadmatColors.lightTextPrimary,
                            fontSize: 15.fz,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          hint ??
                              (isActive
                                  ? 'الخيار مفعل الآن وسيصل الفني إلى موقعك الحالي.'
                                  : isError
                                  ? 'تعذر تحديد الموقع تلقائيًا. اقرأ الرسالة ثم حاول مرة أخرى.'
                                  : 'اضغط لتحديد موقعك الحالي واعتماده كمكان الوصول.'),
                          style: TextStyle(
                            color: isError
                                ? const Color(0xFFA24D4D)
                                : KadmatColors.lightTextSecondary,
                            fontSize: 12.6.fz,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 54.w,
                    height: 30.h,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: isActive
                          ? KadmatColors.stateSuccess
                          : isError
                          ? const Color(0xFFE6B7B0)
                          : const Color(0xFFD7E1E5),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Align(
                      alignment: isActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalPreviewLocationNotice extends StatelessWidget {
  const _LocalPreviewLocationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFD7E3EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2F8),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              Icons.location_searching_rounded,
              color: KadmatColors.brandSecondary,
              size: 24.s,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحديد الموقع التلقائي غير متاح في هذه المعاينة',
                  style: TextStyle(
                    color: KadmatColors.lightTextPrimary,
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'إذا فتحت هذه النسخة عبر عنوان الشبكة مثل 192.168.x.x، فلن يسمح المتصفح بتحديد الموقع تلقائيًا. استخدم الزر اليدوي أسفل هذه البطاقة، أو افتح النسخة عبر localhost أو HTTPS.',
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.8.fz,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualLocationPickerCard extends StatelessWidget {
  const _ManualLocationPickerCard({
    required this.isExpanded,
    required this.hasSelectedLocation,
    required this.hint,
    required this.center,
    required this.selectedPoint,
    required this.onToggle,
    required this.onMapTap,
  });

  final bool isExpanded;
  final bool hasSelectedLocation;
  final String? hint;
  final LatLng center;
  final LatLng? selectedPoint;
  final VoidCallback onToggle;
  final ValueChanged<LatLng> onMapTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: hasSelectedLocation
              ? KadmatColors.stateSuccess.withValues(alpha: 0.3)
              : KadmatColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: hasSelectedLocation
                      ? KadmatColors.stateSuccess.withValues(alpha: 0.12)
                      : KadmatColors.brandAccent,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  hasSelectedLocation
                      ? Icons.add_location_alt_rounded
                      : Icons.map_outlined,
                  color: hasSelectedLocation
                      ? KadmatColors.stateSuccess
                      : KadmatColors.brandPrimary,
                  size: 22.s,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحديد موقعي يدويًا',
                      style: TextStyle(
                        color: KadmatColors.lightTextPrimary,
                        fontSize: 15.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      hasSelectedLocation
                          ? 'تم اختيار مكان الوصول. يمكنك تغيير النقطة من الخريطة.'
                          : 'إذا لم يعمل الموقع التلقائي، افتح الخريطة وحدد نقطة الوصول بنفسك.',
                      style: TextStyle(
                        color: KadmatColors.lightTextSecondary,
                        fontSize: 12.5.fz,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          KadmatSecondaryButton(
            label: isExpanded ? 'إخفاء الخريطة' : 'فتح الخريطة',
            icon: isExpanded ? Icons.expand_less_rounded : Icons.map_rounded,
            onPressed: onToggle,
          ),
          if (isExpanded) ...[
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: SizedBox(
                height: 240.h,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13,
                    onTap: (_, point) => onMapTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kadmat.app',
                    ),
                    if (selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPoint!,
                            width: 42.w,
                            height: 42.w,
                            child: Container(
                              decoration: BoxDecoration(
                                color: KadmatColors.brandPrimary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: KadmatColors.brandPrimary.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.place_rounded,
                                color: Colors.white,
                                size: 24.s,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              hint ??
                  'اضغط على الخريطة لتثبيت مكان الوصول. سيُستخدم هذا الموقع عند إرسال الطلب.',
              style: TextStyle(
                color: hasSelectedLocation
                    ? KadmatColors.stateSuccess
                    : KadmatColors.lightTextSecondary,
                fontSize: 12.4.fz,
                fontWeight: hasSelectedLocation
                    ? FontWeight.w700
                    : FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceOptionChip extends StatelessWidget {
  const _ServiceOptionChip({
    required this.label,
    required this.isCatalogEnabled,
    required this.pricingModeDefault,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isCatalogEnabled;
  final String pricingModeDefault;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final supportsCatalog =
        pricingModeDefault == 'catalog_fixed' || isCatalogEnabled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? KadmatColors.brandSecondary : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected
                  ? KadmatColors.brandSecondary
                  : KadmatColors.lightBorder,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : KadmatColors.lightTextPrimary,
                  fontSize: 13.fz,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              if (supportsCatalog) ...[
                SizedBox(height: 4.h),
                Text(
                  'سعر ثابت',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.86)
                        : KadmatColors.brandSecondary,
                    fontSize: 10.6.fz,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogItemTile extends StatelessWidget {
  const _CatalogItemTile({
    required this.item,
    required this.quantity,
    required this.onChanged,
  });

  final ServiceCatalogItem item;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = item.nameAr?.trim().isNotEmpty == true
        ? item.nameAr!
        : item.name;
    final description = item.descriptionAr?.trim().isNotEmpty == true
        ? item.descriptionAr
        : item.description;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: quantity > 0 ? const Color(0xFFF5FAFF) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: quantity > 0
              ? KadmatColors.brandSecondary.withValues(alpha: 0.28)
              : KadmatColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: KadmatColors.lightTextPrimary,
                        fontSize: 14.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description != null &&
                        description.trim().isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        description,
                        style: TextStyle(
                          color: KadmatColors.lightTextSecondary,
                          fontSize: 12.2.fz,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                '${item.price.toStringAsFixed(2)} د.ل',
                style: TextStyle(
                  color: KadmatColors.brandSecondary,
                  fontSize: 13.6.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove_rounded,
                onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
              ),
              SizedBox(width: 10.w),
              Container(
                constraints: BoxConstraints(minWidth: 42.w),
                alignment: Alignment.center,
                child: Text(
                  quantity.toString(),
                  style: TextStyle(
                    color: KadmatColors.lightTextPrimary,
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              _QuantityButton(
                icon: Icons.add_rounded,
                onPressed: () => onChanged(quantity + 1),
              ),
              const Spacer(),
              if (quantity > 0)
                Text(
                  'المجموع ${(item.price * quantity).toStringAsFixed(2)} د.ل',
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.6.fz,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36.w,
      height: 36.w,
      child: Material(
        color: onPressed == null
            ? const Color(0xFFF1F5F9)
            : KadmatColors.brandAccent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onPressed,
          child: Icon(
            icon,
            color: onPressed == null
                ? KadmatColors.lightTextSecondary.withValues(alpha: 0.5)
                : KadmatColors.brandPrimary,
            size: 18.s,
          ),
        ),
      ),
    );
  }
}

class _CatalogSummaryMetric extends StatelessWidget {
  const _CatalogSummaryMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 11.6.fz,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: highlight
                ? KadmatColors.brandSecondary
                : KadmatColors.lightTextPrimary,
            fontSize: 15.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

InputDecoration _requestInputDecoration(
  BuildContext context, {
  required String hintText,
  Widget? prefixIcon,
  String? suffixText,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixText: suffixText,
    filled: true,
    fillColor: const Color(0xFFFDFEFE),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667E88),
      fontWeight: FontWeight.w500,
      height: 1.5,
    ),
    prefixIconColor: const Color(0xFF54717E),
    suffixStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: KadmatColors.lightTextSecondary,
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: const BorderSide(color: Color(0xFFC9D7DE), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: const BorderSide(
        color: KadmatColors.brandSecondary,
        width: 2,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: const BorderSide(color: Color(0xFFC9D7DE), width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: const BorderSide(color: KadmatColors.stateError, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16.r),
      borderSide: const BorderSide(color: KadmatColors.stateError, width: 1.8),
    ),
    errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: KadmatColors.stateError,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
  );
}
