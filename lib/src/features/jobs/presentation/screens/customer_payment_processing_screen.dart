import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants.dart';
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
  late String _selectedPaymentMethod;

  bool get _supportsOnlinePayments => AppConstants.useRealPayments;

  static const Set<String> _onlineMethods = {'apple_pay', 'credit_card'};

  bool get _isOnlineMethodSelected =>
      _onlineMethods.contains(_selectedPaymentMethod);

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = _supportsOnlinePayments ? 'apple_pay' : 'cash';
    _fetchJob();
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) setState(() => _job = job);
    } catch (_) {
      if (!mounted) return;
      KadmatToast.showError(
        context,
        title: 'خطأ',
        message: 'تعذر تحميل بيانات الدفع. حاول مرة أخرى.',
      );
    }
  }

  Future<void> _processPayment() async {
    if (_isOnlineMethodSelected && !_supportsOnlinePayments) {
      KadmatToast.showInfo(
        context,
        title: 'الدفع الإلكتروني غير متاح',
        message: 'حالياً يمكنك إكمال الطلب عبر خيار الدفع النقدي فقط.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(jobRepositoryProvider)
          .confirmJobCompletion(
            widget.jobId,
            paymentMethod: _selectedPaymentMethod,
          );

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: _selectedPaymentMethod == 'cash'
              ? 'تم تأكيد الدفع النقدي'
              : 'تم تأكيد الدفع الإلكتروني',
          message: 'شكراً لك! تم إكمال الطلب.',
        );
        context.go(AppRoutes.buildCustomerRatePath(widget.jobId));
      }
    } catch (_) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'فشل الدفع',
          message: 'تعذر إتمام العملية. حاول مرة أخرى.',
        );
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
            _buildPaymentMethodTile(
              'apple_pay',
              'Apple Pay',
              Icons.apple,
              enabled: _supportsOnlinePayments,
            ),
            SizedBox(height: 12.h),
            _buildPaymentMethodTile(
              'credit_card',
              'بطاقة مدى / ائتمان',
              Icons.credit_card,
              enabled: _supportsOnlinePayments,
            ),
            SizedBox(height: 12.h),
            _buildPaymentMethodTile(
              'cash',
              'نقداً (تم التسليم للفني)',
              Icons.money,
            ),
            if (!_supportsOnlinePayments) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'الدفع الإلكتروني غير مفعّل حالياً في هذه النسخة.',
                  style: TextStyle(
                    color: Colors.orange.shade200,
                    fontSize: 12.fz,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            SizedBox(height: 48.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading ||
                        (_isOnlineMethodSelected && !_supportsOnlinePayments)
                    ? null
                    : _processPayment,
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
                            : 'تأكيد دفع ${amount.toStringAsFixed(2)} ريال',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16.h),
            if (_isOnlineMethodSelected && _supportsOnlinePayments)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.grey, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'عملية الدفع محمية',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(
    String id,
    String label,
    IconData icon, {
    bool enabled = true,
  }) {
    final isSelected = _selectedPaymentMethod == id;

    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedPaymentMethod = id) : null,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.white.withValues(alpha: 0.03)
              : isSelected
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
              color: !enabled
                  ? Colors.white38
                  : isSelected
                  ? AppTheme.primaryColor
                  : Colors.white70,
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white54,
                fontSize: 16.fz,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (!enabled)
              Text(
                'غير متاح',
                style: TextStyle(
                  color: Colors.orange.shade200,
                  fontSize: 12.fz,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
