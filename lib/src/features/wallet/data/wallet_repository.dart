import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../domain/wallet.dart';

part 'wallet_repository.g.dart';

class WalletRepository {
  final Dio _client;

  WalletRepository(this._client);

  Future<Wallet> getMyWallet() async {
    try {
      final response = await _client.get(Endpoints.wallet);
      return Wallet.fromJson(response.data['wallet']);
    } catch (e) {
      throw Exception('فشل جلب بيانات المحفظة');
    }
  }

  Future<List<WalletTransaction>> getTransactions() async {
    try {
      final response = await _client.get(Endpoints.walletTransactions);
      final List data = response.data['transactions'];
      return data.map((e) => WalletTransaction.fromJson(e)).toList();
    } catch (e) {
      throw Exception('فشل جلب سجل المعاملات');
    }
  }
}

@Riverpod(keepAlive: true)
WalletRepository walletRepository(WalletRepositoryRef ref) {
  final client = ref.watch(apiClientProvider);
  return WalletRepository(client);
}
