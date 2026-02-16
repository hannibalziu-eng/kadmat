import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

part 'wallet_controller.g.dart';

@riverpod
Future<Wallet> myWallet(Ref ref) {
  return ref.watch(walletRepositoryProvider).getWallet();
}

@riverpod
Future<List<WalletTransaction>> myTransactions(Ref ref, {int page = 1}) {
  return ref.watch(walletRepositoryProvider).getTransactions(page: page);
}

@riverpod
Future<List<WithdrawRequest>> myWithdrawRequests(Ref ref, {int page = 1}) {
  return ref.read(walletRepositoryProvider).getWithdrawRequests(page: page);
}

// Controller for actions (like top-up if implemented)
@riverpod
class WalletController extends _$WalletController {
  @override
  FutureOr<void> build() {
    // nothing for now
  }

  Future<void> requestWithdrawal(
    double amount, {
    String? bankAccount,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(walletRepositoryProvider);
      await repository.requestWithdrawal(
        amount: amount,
        bankAccount: bankAccount,
        notes: notes,
      );

      // Refresh wallet balance after withdrawal request
      ref.invalidate(myWalletProvider);
      ref.invalidate(myTransactionsProvider);
      ref.invalidate(myWithdrawRequestsProvider);
    });
  }
}
