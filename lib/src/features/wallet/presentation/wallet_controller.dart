import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

part 'wallet_controller.g.dart';

@riverpod
Future<Wallet> myWallet(MyWalletRef ref) {
  return ref.watch(walletRepositoryProvider).getWallet();
}

@riverpod
Future<List<WalletTransaction>> myTransactions(
  MyTransactionsRef ref, {
  int page = 1,
}) {
  return ref.watch(walletRepositoryProvider).getTransactions(page: page);
}

// Controller for actions (like top-up if implemented)
@riverpod
class WalletController extends _$WalletController {
  @override
  FutureOr<void> build() {
    // nothing for now
  }

  Future<void> requestWithdrawal(double amount) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      // In real app call repository
    });
  }
}
