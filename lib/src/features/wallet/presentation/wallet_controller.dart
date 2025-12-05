import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

part 'wallet_controller.g.dart';

@riverpod
Future<Wallet> myWallet(MyWalletRef ref) {
  return ref.watch(walletRepositoryProvider).getMyWallet();
}

@riverpod
Future<List<WalletTransaction>> myTransactions(MyTransactionsRef ref) {
  return ref.watch(walletRepositoryProvider).getTransactions();
}
