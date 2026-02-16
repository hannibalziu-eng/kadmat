import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../wallet/presentation/wallet_controller.dart';

class TechnicianWalletScreen extends ConsumerWidget {
  const TechnicianWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(myWalletProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('المحفظة'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Earnings Card
            walletAsync.when(
              data: (wallet) => Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12.r,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرصيد القابل للسحب',
                      style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                      style: TextStyle(
                        fontSize: 32.fz,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'إجمالي الأرباح',
                      style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${wallet.totalEarnings.toStringAsFixed(2)} ${wallet.currency}',
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              loading: () => const CardSkeleton(height: 180),
              error: (err, stack) => _buildErrorState(
                context,
                message: _friendlyWalletError(err),
                onRetry: () => ref.invalidate(myWalletProvider),
              ),
            ),
            SizedBox(height: 24.h),

            // Withdraw Button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () => _showWithdrawDialog(
                  context,
                  ref,
                  walletAsync.value?.balance ?? 0,
                ),
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('سحب الأرباح'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 4,
                  shadowColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.3),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2, delay: 100.ms),
            SizedBox(height: 32.h),

            // Action Items
            _buildActionItem(
              context,
              icon: Icons.receipt_long,
              title: 'سجل المعاملات',
              onTap: () => _showTransactionsSheet(context),
            ).animate().fadeIn().slideX(delay: 200.ms),
            SizedBox(height: 12.h),
            _buildActionItem(
              context,
              icon: Icons.credit_card,
              title: 'طلبات السحب',
              onTap: () => _showWithdrawalRequestsSheet(context),
            ).animate().fadeIn().slideX(delay: 250.ms),
            SizedBox(height: 32.h),

            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'أحدث المعاملات',
                  style: TextStyle(
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _showTransactionsSheet(context),
                  child: Text('عرض الكل', style: TextStyle(fontSize: 14.fz)),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
            SizedBox(height: 16.h),

            // Transaction List
            ref
                .watch(myTransactionsProvider())
                .when(
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'لا توجد معاملات بعد',
                        subtitle: 'ستظهر هنا سجلات عملياتك المالية',
                        icon: Icons.receipt_long_rounded,
                      );
                    }
                    return Column(
                      children: transactions
                          .map(
                            (t) => Column(
                              children: [
                                _buildTransactionItem(
                                  context,
                                  title: t.description ?? t.type,
                                  date: _formatTransactionDate(t.createdAt),
                                  amount:
                                      '${t.amount > 0 ? '+' : ''} ${t.amount.toStringAsFixed(2)}',
                                  isIncome: t.amount > 0,
                                ).animate().fadeIn().slideX(),
                                SizedBox(height: 12.h),
                              ],
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const ListSkeleton(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                  ),
                  error: (err, stack) => _buildErrorState(
                    context,
                    message: _friendlyWalletError(err),
                    onRetry: () => ref.invalidate(myTransactionsProvider()),
                  ),
                ),
            SizedBox(height: 80.h), // Bottom nav padding
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8.r,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, size: 22.s),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_left, size: 20.s, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_tethering_error_rounded,
            color: Colors.orange,
            size: 22.s,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13.fz, color: Colors.orange.shade900),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            color: Colors.orange.shade900,
          ),
        ],
      ),
    );
  }

  String _friendlyWalletError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('timeout')) {
      return 'تعذر تحميل بيانات المحفظة الآن. تحقق من اتصال الإنترنت ثم أعد المحاولة.';
    }
    if (normalized.contains('unauthorized') || normalized.contains('jwt')) {
      return 'انتهت صلاحية الجلسة. أعد تسجيل الدخول لمتابعة استخدام المحفظة.';
    }
    return 'تعذر تحميل بيانات المحفظة حالياً. حاول مجدداً بعد قليل.';
  }

  Widget _buildTransactionItem(
    BuildContext context, {
    required String title,
    required String date,
    required String amount,
    required bool isIncome,
  }) {
    final color = isIncome ? Colors.green : Colors.red;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.north_east : Icons.south_west,
              color: color,
              size: 20.s,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  date,
                  style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16.fz,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(
    BuildContext context,
    WidgetRef ref,
    double balance,
  ) {
    final controller = TextEditingController(text: balance.toString());
    final bankAccountController = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سحب الأرباح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل المبلغ الذي تود سحبه:'),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: 'د.ل',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: bankAccountController,
              decoration: const InputDecoration(
                labelText: 'رقم الحساب البنكي (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0 || amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال مبلغ صالح')),
                );
                return;
              }
              Navigator.pop(context);
              try {
                await ref
                    .read(walletControllerProvider.notifier)
                    .requestWithdrawal(
                      amount,
                      bankAccount: bankAccountController.text.trim().isEmpty
                          ? null
                          : bankAccountController.text.trim(),
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال طلب السحب بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_friendlyWalletError(e))),
                  );
                }
              }
            },
            child: const Text('تأكيد السحب'),
          ),
        ],
      ),
    );
  }

  void _showTransactionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final transactionsAsync = ref.watch(myTransactionsProvider());
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سجل المعاملات',
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Expanded(
                      child: transactionsAsync.when(
                        data: (transactions) {
                          if (transactions.isEmpty) {
                            return const EmptyStateWidget(
                              title: 'لا توجد معاملات',
                              subtitle: 'ستظهر المعاملات عند وجود حركة مالية.',
                              icon: Icons.receipt_long_rounded,
                            );
                          }
                          return ListView.separated(
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) => SizedBox(height: 10.h),
                            itemBuilder: (context, index) {
                              final t = transactions[index];
                              return _buildTransactionItem(
                                context,
                                title: t.description ?? t.type,
                                date: _formatTransactionDate(t.createdAt),
                                amount:
                                    '${t.amount > 0 ? '+' : ''} ${t.amount.toStringAsFixed(2)}',
                                isIncome: t.amount > 0,
                              );
                            },
                          );
                        },
                        loading: () =>
                            const ListSkeleton(itemCount: 6, itemHeight: 80),
                        error: (error, _) => _buildErrorState(
                          context,
                          message: _friendlyWalletError(error),
                          onRetry: () =>
                              ref.invalidate(myTransactionsProvider()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawalRequestsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final requestsAsync = ref.watch(myWithdrawRequestsProvider());
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلبات السحب',
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Expanded(
                      child: requestsAsync.when(
                        data: (requests) {
                          if (requests.isEmpty) {
                            return const EmptyStateWidget(
                              title: 'لا توجد طلبات سحب',
                              subtitle: 'عند إرسال طلب سحب سيظهر هنا.',
                              icon: Icons.account_balance_wallet_rounded,
                            );
                          }
                          return ListView.separated(
                            itemCount: requests.length,
                            separatorBuilder: (_, __) => SizedBox(height: 10.h),
                            itemBuilder: (context, index) {
                              final request = requests[index];
                              return Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${request.amount.toStringAsFixed(2)} ${request.currency}',
                                            style: TextStyle(
                                              fontSize: 15.fz,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            _formatTransactionDate(
                                              request.createdAt,
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12.fz,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _withdrawStatusColor(
                                          request.status,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        request.localizedStatus,
                                        style: TextStyle(
                                          fontSize: 12.fz,
                                          color: _withdrawStatusColor(
                                            request.status,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const ListSkeleton(itemCount: 4, itemHeight: 70),
                        error: (error, _) => _buildErrorState(
                          context,
                          message: _friendlyWalletError(error),
                          onRetry: () =>
                              ref.invalidate(myWithdrawRequestsProvider()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _withdrawStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatTransactionDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
