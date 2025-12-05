import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../wallet/presentation/wallet_controller.dart';

class CustomerWalletScreen extends ConsumerWidget {
  const CustomerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(myWalletProvider);

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
                      color: Colors.black.withOpacity(0.05),
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
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 4,
                          shadowColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                        ),
                        child: Text(
                          'إضافة رصيد',
                          style: TextStyle(
                            fontSize: 16.fz,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('خطأ: $err')),
            ),
            SizedBox(height: 32.h),

            // Management Items
            _buildManagementItem(
              context,
              icon: Icons.receipt_long,
              title: 'سجل المعاملات',
              onTap: () {},
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
              title: 'إدارة طرق الدفع',
              onTap: () {},
            ).animate().fadeIn().slideX(delay: 150.ms),
            SizedBox(height: 32.h),

            // Recent Transactions Header
            Text(
              'أحدث المعاملات',
              style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            SizedBox(height: 16.h),

            // Transactions List
            ref
                .watch(myTransactionsProvider)
                .when(
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const Center(child: Text('لا توجد معاملات'));
                    }
                    return Column(
                      children: transactions
                          .map(
                            (t) => Column(
                              children: [
                                _buildTransactionItem(
                                  context,
                                  title: t.description ?? t.type,
                                  date: t.createdAt
                                      .toString(), // Format properly
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                ),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16.fz,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
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
              color: color.withOpacity(0.1),
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
