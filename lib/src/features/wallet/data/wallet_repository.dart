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
    return Wallet.fromJson(
      response.data['data'],
    ); // responseFormatter puts data in 'data'
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
    // Dump raw API response for verification during development
    print('Wallet Transactions Raw Response: ${response.data}');
    // Optional: log with a proper logger in production

    // Check response structure from responseFormatter
    // It usually returns { data: { list: [], pagination: {} } } or similar
    // Based on jobController, it returns successPaginated which is { data: [...], pagination: ... }
    // Wait, getWallet returns success(enrichedJob), so response.data['data'] is correct.
    // Wallet transactions endpoint likely uses successPaginated.
    // walletController not viewed fully, but let's assume standard responseFormatter.
    // successPaginated returns { data: [], pagination: {} } inside the 'data' field of JSON?
    // No, responseFormatter structure is { status: 'success', data: ..., message: ... }
    // For pagination: { status: 'success', data: [...], pagination: ... }

    final data = response.data['data'];
    return (data as List).map((e) => WalletTransaction.fromJson(e)).toList();
  }
}
