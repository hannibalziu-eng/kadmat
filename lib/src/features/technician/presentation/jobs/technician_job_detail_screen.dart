import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../jobs/data/job_repository.dart';
import '../../../jobs/domain/job.dart';

class TechnicianJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianJobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianJobDetailScreen> createState() => _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState extends ConsumerState<TechnicianJobDetailScreen> {
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  StreamSubscription? _jobSubscription;
  Job? _job;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final jobRepo = ref.read(jobRepositoryProvider);
    _jobSubscription = jobRepo.watchJob(widget.jobId).listen((job) {
      if (mounted) {
        setState(() => _job = job);
      }
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _jobSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Badge
            _buildStatusBadge(),
            SizedBox(height: 16.h),

            // Service Info
            _buildInfoCard(
              title: 'الخدمة المطلوبة',
              icon: Icons.build_circle,
              child: Text(
                _job!.service?['name'] ?? 'خدمة',
                style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            SizedBox(height: 12.h),

            // Customer Info
            _buildInfoCard(
              title: 'العميل',
              icon: Icons.person,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _job!.customer?['full_name'] ?? 'عميل',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white),
                  ),
                  if (_job!.customer?['rating'] != null)
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16.s),
                        SizedBox(width: 4.w),
                        Text('${_job!.customer?['rating']}', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Location
            _buildInfoCard(
              title: 'الموقع',
              icon: Icons.location_on,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _job!.addressText ?? 'موقع العميل',
                    style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                  ),
                  SizedBox(height: 8.h),
                  ElevatedButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.map),
                    label: const Text('افتح في الخريطة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Description
            if (_job!.description != null && _job!.description!.isNotEmpty)
              _buildInfoCard(
                title: 'وصف المشكلة',
                icon: Icons.description,
                child: Text(
                  _job!.description!,
                  style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                ),
              ),
            SizedBox(height: 24.h),

            // Action Buttons based on status
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = _job!.status;
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'في انتظار القبول';
        icon = Icons.hourglass_empty;
        break;
      case 'accepted':
        color = Colors.blue;
        text = 'مقبول - أدخل السعر';
        icon = Icons.check_circle;
        break;
      case 'price_pending':
        color = Colors.purple;
        text = 'انتظار موافقة العميل';
        icon = Icons.pending;
        break;
      case 'in_progress':
        color = Colors.green;
        text = 'قيد التنفيذ';
        icon = Icons.work;
        break;
      case 'completed':
        color = Colors.teal;
        text = 'مكتمل';
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        text = status ?? 'غير معروف';
        icon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20.s),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _job!.status;

    switch (status) {
      case 'pending':
        return _buildAcceptButton();
      case 'accepted':
        return _buildPriceInput();
      case 'price_pending':
        return _buildWaitingForCustomer();
      case 'in_progress':
        return _buildCompleteButton();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAcceptButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _acceptJob,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text('قبول الطلب', style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriceInput() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: AppTheme.glassDecoration(radius: 16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحديد السعر',
                style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'أدخل السعر (ريال)',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.attach_money, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ملاحظات (اختياري)',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton(
          onPressed: _isLoading ? null : _setPrice,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send),
                    SizedBox(width: 8.w),
                    Text('إرسال السعر للعميل', style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingForCustomer() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.purple),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 16.h),
          Text(
            'في انتظار موافقة العميل على السعر',
            style: TextStyle(fontSize: 16.fz, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            '${_job!.technicianPrice ?? 0} ريال',
            style: TextStyle(fontSize: 24.fz, fontWeight: FontWeight.bold, color: Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32.s),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'العميل وافق على السعر. قم بإنهاء الخدمة.',
                  style: TextStyle(fontSize: 14.fz, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton(
          onPressed: _isLoading ? null : _completeJob,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.done_all),
                    SizedBox(width: 8.w),
                    Text('إتمام الخدمة', style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _acceptJob() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).acceptJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول الطلب! أدخل السعر الآن.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setPrice() async {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل سعر صحيح'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).setPrice(widget.jobId, price, notes: _notesController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال السعر للعميل'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeJob() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).completeJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 تم إتمام الخدمة بنجاح!'), backgroundColor: Colors.green),
        );
        context.go('/technician/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMaps() async {
    if (_job?.lat != null && _job?.lng != null) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${_job!.lat},${_job!.lng}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }
}
