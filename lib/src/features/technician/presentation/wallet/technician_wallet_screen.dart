import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/kadmat_components.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../wallet/presentation/wallet_controller.dart';

class TechnicianWalletScreen extends ConsumerWidget {
  const TechnicianWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(myWalletProvider);
    final wallet = walletAsync.valueOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WalletHero(
                wallet: wallet,
                onRefresh: () {
                  ref.invalidate(myWalletProvider);
                  ref.invalidate(myTransactionsProvider());
                  ref.invalidate(myWithdrawRequestsProvider());
                },
              ),
              SizedBox(height: 18.h),
              walletAsync.when(
                data: (wallet) => Row(
                  children: [
                    Expanded(
                      child: _WalletStatCard(
                        label: 'القابل للسحب',
                        value:
                            '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                        icon: Icons.account_balance_wallet_outlined,
                        accent: KadmatColors.stateInfo,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _WalletStatCard(
                        label: 'إجمالي الأرباح',
                        value:
                            '${wallet.totalEarnings.toStringAsFixed(2)} ${wallet.currency}',
                        icon: Icons.trending_up_rounded,
                        accent: KadmatColors.stateSuccess,
                      ),
                    ),
                  ],
                ),
                loading: () => const CardSkeleton(height: 168),
                error: (err, _) => _buildErrorState(
                  context,
                  message: _friendlyWalletError(err),
                  onRetry: () => ref.invalidate(myWalletProvider),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: KadmatPrimaryButton(
                      label: 'سحب الأرباح',
                      icon: Icons.account_balance_wallet_outlined,
                      onPressed: wallet == null
                          ? null
                          : () => _showWithdrawDialog(
                              context,
                              ref,
                              wallet.balance,
                            ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: KadmatSecondaryButton(
                      label: 'طلبات السحب',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => _showWithdrawalRequestsSheet(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              _ActionStripCard(
                icon: Icons.receipt_long_rounded,
                title: 'سجل المعاملات',
                subtitle: 'راجع كل حركة دخل أو خصم على المحفظة',
                onTap: () => _showTransactionsSheet(context),
              ),
              SizedBox(height: 24.h),
              KadmatSectionHeader(
                title: 'أحدث المعاملات',
                subtitle: 'آخر التحديثات المالية على حسابك المهني.',
                trailing: TextButton(
                  onPressed: () => _showTransactionsSheet(context),
                  child: const Text('عرض الكل'),
                ),
              ),
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: KadmatColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ref
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
                              .take(4)
                              .map(
                                (t) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _buildTransactionItem(
                                    context,
                                    title: t.description ?? t.type,
                                    date: _formatTransactionDate(t.createdAt),
                                    amount:
                                        '${t.amount > 0 ? '+' : ''} ${t.amount.toStringAsFixed(2)}',
                                    isIncome: t.amount > 0,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                      loading: () => const ListSkeleton(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                      ),
                      error: (err, _) => _buildErrorState(
                        context,
                        message: _friendlyWalletError(err),
                        onRetry: () => ref.invalidate(myTransactionsProvider()),
                      ),
                    ),
              ),
              SizedBox(height: 80.h),
            ],
          ),
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
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_tethering_error_rounded,
            color: KadmatColors.stateWarning,
            size: 22.s,
          ),
          SizedBox(width: 10.w),
          Expanded(child: Text(message)),
          IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            color: KadmatColors.stateWarning,
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
    final color = isIncome
        ? KadmatColors.stateSuccess
        : KadmatColors.stateError;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: color,
              size: 20.s,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(date, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15.fz,
              fontWeight: FontWeight.w800,
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

class _WalletHero extends StatelessWidget {
  const _WalletHero({required this.wallet, required this.onRefresh});

  final dynamic wallet;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final balanceLabel = wallet == null
        ? 'جاري تحميل الرصيد...'
        : '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF18323C), Color(0xFF102129)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'محفظتك المهنية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.fz,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'تابع الرصيد، المعاملات، وطلبات السحب من مكان واحد واضح وسريع.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13.fz,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرصيد الحالي',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.fz,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.fz,
                    fontWeight: FontWeight.w800,
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

class _WalletStatCard extends StatelessWidget {
  const _WalletStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: accent, size: 18.s),
          ),
          SizedBox(height: 12.h),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 4.h),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ActionStripCard extends StatelessWidget {
  const _ActionStripCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(24.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: KadmatColors.brandAccent,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  icon,
                  size: 22.s,
                  color: KadmatColors.brandSecondary,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                size: 22.s,
                color: KadmatColors.lightTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
