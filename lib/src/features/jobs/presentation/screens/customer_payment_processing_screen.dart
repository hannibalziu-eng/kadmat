import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants.dart';
import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/utils/service_name_formatter.dart';
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

  List<({String id, String label, IconData icon})> get _availableMethods {
    if (_supportsOnlinePayments) {
      return const [
        (id: 'apple_pay', label: 'Apple Pay', icon: Icons.apple),
        (
          id: 'credit_card',
          label: 'بطاقة مدى / ائتمان',
          icon: Icons.credit_card,
        ),
        (id: 'cash', label: 'نقداً (تم التسليم للفني)', icon: Icons.money),
      ];
    }

    return const [
      (id: 'cash', label: 'نقداً (تم التسليم للفني)', icon: Icons.money),
    ];
  }

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final amount = _job!.finalPrice ?? _job!.technicianPrice ?? 0;
    final serviceName = formatServiceDisplayName(
      _job!.service,
      fallback: 'الخدمة المطلوبة',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('الدفع'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(serviceName, amount),
                SizedBox(height: 16.h),
                _buildSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختر طريقة الدفع',
                        style: TextStyle(
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 18.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'أظهرنا هنا فقط الطرق التي يمكن تنفيذها فعليًا في هذه النسخة حتى لا تدخل في خطوة وهمية أو غير مكتملة.',
                        style: TextStyle(
                          color: KadmatColors.lightTextSecondary,
                          fontSize: 12.5.fz,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      for (final method in _availableMethods) ...[
                        _buildPaymentMethodTile(
                          method.id,
                          method.label,
                          method.icon,
                        ),
                        SizedBox(height: 12.h),
                      ],
                    ],
                  ),
                ),
                if (!_supportsOnlinePayments) ...[
                  SizedBox(height: 16.h),
                  _buildSurface(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدفع الإلكتروني مؤجل في هذه النسخة',
                            style: TextStyle(
                              color: const Color(0xFF935C1B),
                              fontSize: 13.fz,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'حالياً يتم إكمال الطلب عبر تأكيد التسليم النقدي فقط. سنضيف طرق الدفع الإلكترونية لاحقاً عندما تكون جاهزة تشغيلياً في السوق المستهدف.',
                            style: TextStyle(
                              color: KadmatColors.lightTextSecondary,
                              fontSize: 12.5.fz,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                _buildSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماذا سيحدث بعد التأكيد؟',
                        style: TextStyle(
                          color: KadmatColors.lightTextPrimary,
                          fontSize: 18.fz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildBullet(
                        'سيتم تسجيل طريقة الدفع المعتمدة على الطلب الحالي.',
                      ),
                      SizedBox(height: 10.h),
                      _buildBullet(
                        'تنتقل مباشرة بعد ذلك إلى خطوة التقييم النهائية.',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ||
                            (_isOnlineMethodSelected &&
                                !_supportsOnlinePayments)
                        ? null
                        : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _selectedPaymentMethod == 'cash'
                                ? 'تأكيد التسليم النقدي'
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
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: KadmatColors.lightTextSecondary,
                          size: 16.s,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'عملية الدفع محمية',
                          style: TextStyle(
                            color: KadmatColors.lightTextSecondary,
                            fontSize: 12.fz,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(String serviceName, double amount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17313B), Color(0xFF0D1E25)],
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
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 22.s,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'خطوة الدفع',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'أكمل الطلب بطريقة واضحة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'اختر الطريقة المتاحة، أكد العملية، ثم انتقل مباشرة إلى التقييم النهائي.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildHeroPill(Icons.work_outline_rounded, serviceName),
              _buildHeroPill(
                Icons.attach_money_rounded,
                '${amount.toStringAsFixed(0)} ر.س',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15.s),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5.fz,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: child,
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          margin: EdgeInsets.only(top: 6.h),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 12.8.fz,
              height: 1.5,
            ),
          ),
        ),
      ],
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
              : KadmatColors.lightSurface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : KadmatColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : KadmatColors.lightTextSecondary,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: KadmatColors.lightTextPrimary,
                  fontSize: 15.fz,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
