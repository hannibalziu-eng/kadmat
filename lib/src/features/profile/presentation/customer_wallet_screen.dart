import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/utils/error_handler.dart';
import '../../wallet/presentation/wallet_controller.dart';

class CustomerWalletScreen extends ConsumerWidget {
  const CustomerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(myWalletProvider);
    final recentTransactionsAsync = ref.watch(myTransactionsProvider(page: 1));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('المحفظة'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
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
                  children: [
                    Text(
                      'رصيدك الحالي',
                      style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                      style: TextStyle(
                        fontSize: 36.fz,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).scaffoldBackgroundColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18.s,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'تعرض هذه الصفحة رصيدك وسجل المعاملات فقط. الدفع يتم عند إتمام الخدمة، وسيظهر شحن الرصيد وطرق الدفع الإلكترونية عند تفعيل البوابة.',
                              style: TextStyle(
                                fontSize: 13.fz,
                                height: 1.45,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  ErrorHandler.getMessage(err),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 32.h),

            // Management Items
            _buildManagementItem(
              context,
              icon: Icons.receipt_long,
              title: 'سجل المعاملات',
              subtitle: 'عرض كل الحركات المالية بالتفصيل',
              onTap: () => context.push(AppRoutes.customerWalletTransactions),
            ).animate().fadeIn().slideX(delay: 100.ms),
            Divider(
              height: 1.h,
              thickness: 1.h,
              indent: 56.w,
              color: Theme.of(context).dividerColor,
            ),
            _buildManagementItem(
              context,
              icon: Icons.credit_card,
              title: 'طرق الدفع الإلكترونية',
              subtitle: 'سيتم تفعيلها عند ربط بوابة الدفع',
              enabled: false,
            ).animate().fadeIn().slideX(delay: 150.ms),
            SizedBox(height: 32.h),

            // Recent Transactions Header
            Text(
              'أحدث المعاملات',
              style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 16.h),

            // Transactions List
            recentTransactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('لا توجد معاملات'));
                }
                return Column(
                  children: transactions
                      .take(3)
                      .map(
                        (t) => Column(
                          children: [
                            _buildTransactionItem(
                              context,
                              title: t.description ?? t.type,
                              date: DateFormat(
                                'yyyy/MM/dd - HH:mm',
                              ).format(t.createdAt),
                              amount:
                                  '${t.amount > 0 ? '+' : ''} ${t.amount.toStringAsFixed(2)}',
                              isPayment: t.amount < 0,
                            ).animate().fadeIn().slideX(),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  ErrorHandler.getMessage(err),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (recentTransactionsAsync.valueOrNull != null &&
                recentTransactionsAsync.valueOrNull!.length > 3) ...[
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      context.push(AppRoutes.customerWalletTransactions),
                  child: const Text('عرض السجل الكامل'),
                ),
              ),
            ],
            SizedBox(height: 80.h), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildManagementItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                icon,
                size: 22.s,
                color: Theme.of(context).primaryColor,
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
                      fontWeight: FontWeight.normal,
                      color: enabled ? null : Colors.grey,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            if (!enabled)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  'لاحقًا',
                  style: TextStyle(fontSize: 11.fz, color: Colors.white54),
                ),
              ),
            if (enabled)
              Icon(Icons.chevron_right, size: 20.s, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context, {
    required String title,
    required String date,
    required String amount,
    required bool isPayment,
  }) {
    final color = isPayment ? Colors.red : Colors.green;
    final icon = isPayment ? Icons.arrow_upward : Icons.arrow_downward;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20.s),
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
              fontWeight: FontWeight.w600,
              color: isPayment
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : color,
            ),
          ),
        ],
      ),
    );
  }
}
