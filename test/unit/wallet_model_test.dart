import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/wallet/domain/wallet.dart';

void main() {
  group('Wallet.fromApiJson', () {
    test('parses minimal wallet payloads returned by backend', () {
      final wallet = Wallet.fromApiJson({
        'id': 'wallet-1',
        'user_id': 'user-1',
        'balance': 0,
        'currency': 'SAR',
        'updated_at': '2026-03-07T00:00:00.000Z',
      });

      expect(wallet.id, 'wallet-1');
      expect(wallet.userId, 'user-1');
      expect(wallet.balance, 0);
      expect(wallet.totalEarnings, 0);
      expect(wallet.currency, 'د.ل');
      expect(wallet.updatedAt, DateTime.parse('2026-03-07T00:00:00.000Z'));
      expect(wallet.createdAt, wallet.updatedAt);
    });

    test('parses transactions with missing optional fields safely', () {
      final transaction = WalletTransaction.fromApiJson({
        'id': 'tx-1',
        'wallet_id': 'wallet-1',
        'amount': '-25.5',
        'type': 'withdrawal',
      });

      expect(transaction.id, 'tx-1');
      expect(transaction.walletId, 'wallet-1');
      expect(transaction.amount, -25.5);
      expect(transaction.type, 'withdrawal');
    });
  });
}
