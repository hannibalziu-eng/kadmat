import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../wallet/presentation/wallet_controller.dart';
import '../../../wallet/domain/wallet.dart';

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
                      color: Colors.black.withOpacity(0.05),
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
                      '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}', // TODO: Add total earnings field to Wallet model
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.2),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('خطأ: $err')),
            ),
            SizedBox(height: 24.h),

            // Withdraw Button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('سحب الأرباح'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 4,
                  shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2, delay: 100.ms),
            SizedBox(height: 32.h),

            // Action Items
            _buildActionItem(
              context,
              icon: Icons.receipt_long,
              title: 'سجل المعاملات',
              onTap: () {},
            ).animate().fadeIn().slideX(delay: 200.ms),
            SizedBox(height: 12.h),
            _buildActionItem(
              context,
              icon: Icons.credit_card,
              title: 'إدارة طرق السحب',
              onTap: () {},
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
                  onPressed: () {},
                  child: Text('عرض الكل', style: TextStyle(fontSize: 14.fz)),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
            SizedBox(height: 16.h),

            // Transaction List
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
                                  isIncome: t.amount > 0,
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
              color: Colors.black.withOpacity(0.04),
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
            color: Colors.black.withOpacity(0.04),
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
              color: color.withOpacity(0.1),
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
}
