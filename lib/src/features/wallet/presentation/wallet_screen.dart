import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'wallet_controller.dart';
import '../domain/wallet.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(myWalletProvider);
    final transactionsAsync = ref.watch(myTransactionsProvider(page: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myWalletProvider);
          ref.invalidate(myTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Card
              _buildBalanceCard(context, walletAsync),

              const SizedBox(height: 24),

              Text(
                'آخر العمليات',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // Transactions List
              _buildTransactionsList(context, transactionsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    AsyncValue<Wallet> walletAsync,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'الرصيد الحالي',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            walletAsync.when(
              data: (wallet) {
                final isNegative = wallet.balance < 0;
                return Text(
                  '${wallet.balance.abs().toStringAsFixed(2)} ${wallet.currency}',
                  style: TextStyle(
                    color: isNegative
                        ? Colors.redAccent.shade100
                        : Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
              loading: () =>
                  const CircularProgressIndicator(color: Colors.white),
              error: (_, __) => const Text(
                '---',
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
            ),
            if (walletAsync.hasValue && walletAsync.value!.balance < 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: const Text(
                  'لديك مستحقات غير مسددة',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خاصية شحن الرصيد قريباً...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('شحن الرصيد'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    AsyncValue<List<WalletTransaction>> transactionsAsync,
  ) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا توجد عمليات سابقة'),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isCredit = tx.amount >= 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isCredit
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              title: Text(tx.description ?? tx.type),
              subtitle: Text(
                DateFormat('yyyy/MM/dd HH:mm').format(tx.createdAt),
              ),
              trailing: Text(
                '${isCredit ? '+' : ''}${tx.amount} ريال',
                style: TextStyle(
                  color: isCredit ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطأ: $err')),
    );
  }
}
