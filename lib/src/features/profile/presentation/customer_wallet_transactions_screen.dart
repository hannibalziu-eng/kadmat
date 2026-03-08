import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:intl/intl.dart';

import '../../wallet/domain/wallet.dart';
import '../../wallet/presentation/wallet_controller.dart';

class CustomerWalletTransactionsScreen extends ConsumerWidget {
  const CustomerWalletTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(myTransactionsProvider(page: 1));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('سجل المعاملات'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTransactionsProvider(page: 1));
          await ref.read(myTransactionsProvider(page: 1).future);
        },
        child: transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 140.h),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64.s,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16.h),
                  Center(
                    child: Text(
                      'لا توجد معاملات حتى الآن',
                      style: TextStyle(fontSize: 16.fz, color: Colors.white60),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                return _TransactionCard(transaction: transactions[index]);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: 140.h),
              Center(
                child: Text(
                  'تعذر تحميل المعاملات',
                  style: TextStyle(fontSize: 16.fz, color: Colors.white70),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Text(
                  error.toString(),
                  style: TextStyle(fontSize: 12.fz, color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.amount < 0;
    final accent = isDebit ? Colors.redAccent : Colors.green;
    final formatter = DateFormat('yyyy/MM/dd - HH:mm');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDebit
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: accent,
              size: 22.s,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description?.trim().isNotEmpty == true
                      ? transaction.description!
                      : transaction.type,
                  style: TextStyle(
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  formatter.format(transaction.createdAt),
                  style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                ),
                if (transaction.referenceId?.trim().isNotEmpty == true) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'مرجع العملية: ${transaction.referenceId}',
                    style: TextStyle(fontSize: 12.fz, color: Colors.white54),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            '${isDebit ? '' : '+'}${transaction.amount.toStringAsFixed(2)} ر.س',
            style: TextStyle(
              color: accent,
              fontSize: 15.fz,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
