import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/profile/presentation/customer_wallet_screen.dart';
import 'package:kadmat/src/features/profile/presentation/customer_wallet_transactions_screen.dart';
import 'package:kadmat/src/features/wallet/domain/wallet.dart';
import 'package:kadmat/src/features/wallet/presentation/wallet_controller.dart';

void main() {
  final wallet = Wallet(
    id: 'wallet-1',
    userId: 'customer-1',
    balance: 42,
    currency: 'SAR',
    createdAt: DateTime(2026, 3, 7),
    updatedAt: DateTime(2026, 3, 7),
  );

  final transactions = [
    WalletTransaction(
      id: 'tx-1',
      walletId: 'wallet-1',
      amount: -95,
      type: 'payment',
      description: 'دفع خدمة صيانة',
      createdAt: DateTime(2026, 3, 7, 12, 0),
    ),
    WalletTransaction(
      id: 'tx-2',
      walletId: 'wallet-1',
      amount: 20,
      type: 'refund',
      description: 'استرداد جزئي',
      createdAt: DateTime(2026, 3, 7, 13, 0),
    ),
    WalletTransaction(
      id: 'tx-3',
      walletId: 'wallet-1',
      amount: -15,
      type: 'fee',
      description: 'رسوم خدمة',
      createdAt: DateTime(2026, 3, 7, 14, 0),
    ),
    WalletTransaction(
      id: 'tx-4',
      walletId: 'wallet-1',
      amount: 10,
      type: 'adjustment',
      description: 'تسوية',
      createdAt: DateTime(2026, 3, 7, 15, 0),
    ),
  ];

  testWidgets(
    'CustomerWalletScreen focuses on supported wallet data and full history route',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myWalletProvider.overrideWith((ref) async => wallet),
            myTransactionsProvider(
              page: 1,
            ).overrideWith((ref) async => transactions),
          ],
          child: const MaterialApp(home: CustomerWalletScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('42.00 د.ل'), findsOneWidget);
      expect(find.text('إضافة رصيد'), findsNothing);
      expect(find.text('سجل المعاملات'), findsOneWidget);
      expect(find.text('عرض السجل الكامل'), findsOneWidget);
      expect(find.text('طرق الدفع الإلكترونية'), findsOneWidget);
      expect(find.text('لاحقًا'), findsOneWidget);
    },
  );

  testWidgets('CustomerWalletTransactionsScreen renders real transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myTransactionsProvider(
            page: 1,
          ).overrideWith((ref) async => transactions),
        ],
        child: const MaterialApp(home: CustomerWalletTransactionsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('دفع خدمة صيانة'), findsOneWidget);
    expect(find.text('استرداد جزئي'), findsOneWidget);
    expect(find.textContaining('د.ل'), findsWidgets);
    expect(find.text('لا توجد معاملات حتى الآن'), findsNothing);
  });
}
