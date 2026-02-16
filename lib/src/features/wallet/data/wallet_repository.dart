import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadmat/src/core/api/api_client.dart';
import '../domain/wallet.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.read(apiClientProvider));
});

class WalletRepository {
  final Dio _dio;

  WalletRepository(this._dio);

  /// Get Wallet Balance and Details
  Future<Wallet> getWallet() async {
    final response = await _dio.get('/wallet');
    final data =
        response.data['data'] ??
        response.data['wallet'] ??
        response.data['result'];
    return Wallet.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get Wallet Transactions (Paginated)
  Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/wallet/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );

    final data =
        response.data['data'] ??
        response.data['transactions'] ??
        const <dynamic>[];
    return (data as List).map((e) => WalletTransaction.fromJson(e)).toList();
  }

  /// Request Withdrawal
  Future<WithdrawRequest> requestWithdrawal({
    required double amount,
    String? bankAccount,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/wallet/withdraw',
      data: {
        'amount': amount,
        if (bankAccount != null) 'bank_account': bankAccount,
        if (notes != null) 'notes': notes,
      },
    );

    final data = response.data['data'] ?? const <String, dynamic>{};
    return WithdrawRequest.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<WithdrawRequest>> getWithdrawRequests({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/wallet/withdrawals',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] ?? const <dynamic>[];
    return (data as List)
        .map((e) => WithdrawRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
