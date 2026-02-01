import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';

class CustomerPaymentProcessingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerPaymentProcessingScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerPaymentProcessingScreen> createState() =>
      _CustomerPaymentProcessingScreenState();
}

class _CustomerPaymentProcessingScreenState
    extends ConsumerState<CustomerPaymentProcessingScreen> {
  Job? _job;
  bool _isLoading = false;
  String _selectedPaymentMethod = 'apple_pay'; // Default

  @override
  void initState() {
    super.initState();
    _fetchJob();
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) setState(() => _job = job);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);

    // Mock payment delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Confirm job completion (which implies payment success in this mock)
      await ref.read(jobRepositoryProvider).confirmJobCompletion(widget.jobId);

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم الدفع بنجاح',
          message: 'شكراً لك! تم إكمال الطلب.',
        );
        // Navigate to Rate Screen
        context.go(AppRoutes.buildCustomerRatePath(widget.jobId));
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(context, title: 'خطأ', message: 'فشل الدفع: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    final amount = _job!.finalPrice ?? _job!.technicianPrice ?? 0;
    // Add dummy tax/fees for display if needed, but using finalPrice acts as Total for now.

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('الدفع'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            // Amount Card
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                children: [
                  Text(
                    'المبلغ الإجمالي',
                    style: TextStyle(color: Colors.white70, fontSize: 16.fz),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${amount.toStringAsFixed(2)} ريال',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32.h),

            // Payment Methods
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اختر طريقة الدفع',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.fz,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 16.h),

            _buildPaymentMethodTile('apple_pay', 'Apple Pay', Icons.apple),
            SizedBox(height: 12.h),
            _buildPaymentMethodTile(
              'credit_card',
              'بطاقة مدى / ائتمان',
              Icons.credit_card,
            ),
            SizedBox(height: 12.h),
            _buildPaymentMethodTile(
              'cash',
              'نقداً (تم التسليم للفني)',
              Icons.money,
            ),

            SizedBox(height: 48.h),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _selectedPaymentMethod == 'cash'
                            ? 'تأكيد التسليم'
                            : 'ادفع ${amount.toStringAsFixed(2)} ريال',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16.h),
            if (_selectedPaymentMethod != 'cash')
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.grey, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'الدفع آمن ومشفر 100%',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(String id, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.white70,
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.fz,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
