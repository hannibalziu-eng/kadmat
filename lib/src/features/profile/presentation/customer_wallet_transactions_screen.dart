import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:intl/intl.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/utils/error_handler.dart';
import '../../wallet/domain/wallet.dart';
import '../../wallet/presentation/wallet_controller.dart';

class CustomerWalletTransactionsScreen extends ConsumerWidget {
  const CustomerWalletTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(myTransactionsProvider(page: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(title: const Text('سجل المعاملات'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 920.w),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myTransactionsProvider(page: 1));
                await ref.read(myTransactionsProvider(page: 1).future);
              },
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.w),
                      children: const [
                        _HeroCard(),
                        SizedBox(height: 16),
                        _InfoCard(
                          icon: Icons.receipt_long_outlined,
                          title: 'لا توجد معاملات حتى الآن',
                          description:
                              'عندما تُسجّل أول حركة على المحفظة ستظهر هنا بترتيب زمني واضح، مع وصف موجز ومبلغ العملية.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16.w),
                    itemCount: transactions.length + 2,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      if (index == 0) return const _HeroCard();
                      if (index == 1) {
                        return const _InfoCard(
                          icon: Icons.track_changes_outlined,
                          title: 'ما الذي تراه هنا؟',
                          description:
                              'هذا السجل يعرض كل حركة مالية على المحفظة من الأحدث إلى الأقدم. اسحب للأسفل للتحديث عند الحاجة.',
                        );
                      }
                      return _TransactionCard(
                        transaction: transactions[index - 2],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  children: [
                    const _HeroCard(),
                    SizedBox(height: 16.h),
                    _InfoCard(
                      icon: Icons.error_outline,
                      title: 'تعذر تحميل المعاملات',
                      description: ErrorHandler.getMessage(error),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 22.s,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'تابع حركة محفظتك بسهولة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'السجل هنا مخصص للمراجعة فقط: متى دخل مبلغ، متى خرج، وما الوصف المرتبط بكل عملية.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandAccent,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: KadmatColors.brandSecondary, size: 22.s),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: KadmatColors.lightTextPrimary,
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 12.5.fz,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final accent = isDebit ? const Color(0xFFB23A48) : const Color(0xFF2E9B62);
    final formatter = DateFormat('yyyy/MM/dd - HH:mm');

    return _Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16.r),
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
                    fontWeight: FontWeight.w800,
                    color: KadmatColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  formatter.format(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 12.fz,
                    color: KadmatColors.lightTextSecondary,
                  ),
                ),
                if (transaction.referenceId?.trim().isNotEmpty == true) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'مرجع العملية: ${transaction.referenceId}',
                    style: TextStyle(
                      fontSize: 12.fz,
                      color: KadmatColors.lightTextSecondary,
                    ),
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
