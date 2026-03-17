import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadmat/src/core/app_theme.dart';
import 'package:kadmat/src/core/utils/error_handler.dart';
import 'package:kadmat/src/core/widgets/kadmat_toast.dart';
import 'package:kadmat/src/core/widgets/shared_components.dart';
import 'package:kadmat/src/features/bidding/presentation/widgets/countdown_timer.dart';
import 'package:kadmat/src/features/jobs/domain/job.dart';
import 'package:kadmat/src/features/jobs/data/job_repository.dart';
import 'package:kadmat/src/core/exceptions/app_exceptions.dart';

class TechnicianBiddingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianBiddingScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianBiddingScreen> createState() =>
      _TechnicianBiddingScreenState();
}

class _TechnicianBiddingScreenState
    extends ConsumerState<TechnicianBiddingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  // Changed from controller to state variable for dropdown
  int? _selectedDuration;
  final List<int> _selectedDays = [];

  bool _isLoading = false;
  Job? _job;
  StreamSubscription<Job>? _jobSubscription;

  @override
  void initState() {
    super.initState();
    // Watch job details
    _jobSubscription = ref
        .read(jobRepositoryProvider)
        .watchJob(widget.jobId)
        .listen((job) {
          if (mounted) {
            setState(() => _job = job);
            // If job status changes away from searching/pending, nav away?
            // For now, we assume this screen is valid only when job is open.
          }
        });
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitBid() async {
    if (!_formKey.currentState!.validate()) return;
    if (_job == null) return;
    if (!_isJobOpenForBids(_job!)) {
      KadmatToast.showWarning(
        context,
        title: 'الطلب غير متاح',
        message: 'هذا الطلب لم يعد متاحاً لتقديم عرض',
      );
      return;
    }

    setState(() => _isLoading = true);

    final amount = double.parse(_priceController.text);

    try {
      // Use the backend API contract used by the production flow.
      // This avoids direct-RLS edge cases during local/staging runs.
      await ref.read(jobRepositoryProvider).submitOffer(_job!.id, amount);

      if (!mounted) return;
      setState(() => _isLoading = false);
      KadmatToast.showSuccess(
        context,
        title: 'تم تقديم العرض بنجاح',
        message: 'ننتظر موافقة العميل',
      );
      context.pop(); // Return to previous screen
    } on InvalidStatusException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      KadmatToast.showError(
        context,
        title: 'فشل تقديم العرض',
        message: e.message,
      );
    } on JobAlreadyAcceptedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      KadmatToast.showWarning(
        context,
        title: 'الطلب لم يعد متاحًا',
        message: e.message,
      );
    } on JobNotFoundException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      KadmatToast.showError(
        context,
        title: 'الطلب غير موجود',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      KadmatToast.showError(
        context,
        title: 'فشل تقديم العرض',
        message: ErrorHandler.getMessage(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Determine timer end time - ideally from job creation + 15 mins
    // Or from a specific field. Assuming createdAt + 15 mins for now.
    // If not present, default to now + 5 mins (fallback)
    final createdAt = _job!.createdAt; // Job entity should have this
    final endsAt = createdAt.add(const Duration(minutes: 15));
    final isOpenForBids = _isJobOpenForBids(_job!);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تقديم عرض'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isOpenForBids) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'تم إغلاق هذا الطلب أو تم إسناده بالفعل',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            // Timer
            CountdownTimer(
              endsAt: endsAt,
              onExpired: () {
                // Handle expiry: maybe disable inputs or show message
                if (mounted) {
                  KadmatToast.showInfo(
                    context,
                    title: 'انتهى الوقت',
                    message: 'انتهت فترة تقديم العروض لهذا الطلب',
                  );
                  context.pop();
                }
              },
              onExtend: () {
                // Not implemented for Technician, usually Customer extends
              },
              canExtend: false, // Technician cannot extend
            ),
            const SizedBox(height: 24),

            // Job Summary
            _buildJobSummaryCard(),
            const SizedBox(height: 24),

            // Bid Form
            _buildBidForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildJobSummaryCard() {
    final initialPrice = _job!.initialPrice;
    final hasInitialPrice = initialPrice != null && initialPrice > 0;
    final mediaItems = _job!.images ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'تفاصيل الطلب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildDetailRow(
            'الخدمة',
            (_job!.service?['name_ar'] ?? _job!.service?['name'] ?? 'غير محدد')
                .toString(),
            Icons.build,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'الموقع',
            _job!.addressText ?? 'موقع العميل',
            Icons.location_on,
          ),
          if (_job!.description != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('الوصف', _job!.description!, Icons.description),
          ],
          if (hasInitialPrice) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              'السعر المتوقع من العميل',
              '${initialPrice.toStringAsFixed(0)} د.ل',
              Icons.attach_money,
            ),
          ],
          if (mediaItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'المرفقات',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mediaItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = mediaItems[index];
                  final isVideo = (item.mediaType ?? '').toLowerCase().contains(
                    'video',
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          item.imageUrl,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 76,
                            height: 76,
                            color: Colors.white10,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        if (isVideo)
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBidForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'عرضك',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Price Input
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'السعر المقترح (د.ل)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(
                Icons.monetization_on,
                color: AppTheme.secondaryColor,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'الرجاء إدخال السعر';

              final price = double.tryParse(value);
              if (price == null || price <= 0) return 'السعر غير صالح';

              if (price < 10) return 'الحد الأدنى 10 د.ل';

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Duration Dropdown (replaced text field)
          DropdownButtonFormField<int>(
            initialValue: _selectedDuration,
            dropdownColor: AppTheme.backgroundDark,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'المدة المتوقعة',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(
                Icons.timer,
                color: AppTheme.secondaryColor,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
              DropdownMenuItem(value: 60, child: Text('1 ساعة')),
              DropdownMenuItem(value: 90, child: Text('1.5 ساعة')),
              DropdownMenuItem(value: 120, child: Text('2 ساعات')),
              DropdownMenuItem(value: 180, child: Text('3 ساعات')),
              DropdownMenuItem(value: 240, child: Text('4 ساعات')),
            ],
            onChanged: (value) => setState(() => _selectedDuration = value),
            validator: (value) => value == null ? 'الرجاء اختيار المدة' : null,
          ),
          const SizedBox(height: 16),

          // Availability Days
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أيام التوفر:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDayChip('الأحد', 0),
                  _buildDayChip('الإثنين', 1),
                  _buildDayChip('الثلاثاء', 2),
                  _buildDayChip('الأربعاء', 3),
                  _buildDayChip('الخميس', 4),
                  _buildDayChip('الجمعة', 5),
                  _buildDayChip('السبت', 6),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes Input
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'ملاحظات إضافية (اختياري)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(
                Icons.note,
                color: AppTheme.secondaryColor,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Submit Button
          PrimaryButton(
            text: 'تقديم العرض',
            onPressed: _isJobOpenForBids(_job!) ? () => _submitBid() : null,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  bool _isJobOpenForBids(Job job) {
    const openStatuses = {'pending', 'searching', 'no_technician_found'};
    return openStatuses.contains(job.status) && job.technicianId == null;
  }

  Widget _buildDayChip(String label, int value) {
    final isSelected = _selectedDays.contains(value);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.secondaryColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(value);
          } else {
            _selectedDays.add(value);
          }
        });
      },
    );
  }
}
