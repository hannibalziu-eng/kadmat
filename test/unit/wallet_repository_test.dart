import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/wallet/data/wallet_repository.dart';
import 'package:kadmat/src/features/wallet/domain/wallet.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([Dio])
import 'wallet_repository_test.mocks.dart';

void main() {
  group('WalletRepository Tests', () {
    late WalletRepository repository;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      repository = WalletRepository(mockDio);
    });

    test('getMyWallet should return wallet data', () async {
      // Arrange
      final mockResponse = {
        'id': 'wallet-1',
        'user_id': 'user-1',
        'balance': 500.0,
        'currency': 'SAR',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      when(mockDio.get(any)).thenAnswer(
        (_) async => Response(
          data: {'wallet': mockResponse},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/wallet'),
        ),
      );

      // Act
      final result = await repository.getMyWallet();

      // Assert
      expect(result, isA<Wallet>());
      expect(result.balance, 500.0);
      verify(mockDio.get(any)).called(1);
    });

    test('getTransactions should return list of transactions', () async {
      // Arrange
      final mockResponse = [
        {
          'id': 'tx-1',
          'wallet_id': 'wallet-1',
          'amount': 100.0,
          'type': 'credit',
          'description': 'Payment for job',
          'created_at': '2024-01-01T00:00:00Z',
        },
        {
          'id': 'tx-2',
          'wallet_id': 'wallet-1',
          'amount': 50.0,
          'type': 'debit',
          'description': 'Commission',
          'created_at': '2024-01-02T00:00:00Z',
        },
      ];

      when(mockDio.get(any)).thenAnswer(
        (_) async => Response(
          data: {'transactions': mockResponse},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/wallet/transactions'),
        ),
      );

      // Act
      final result = await repository.getTransactions();

      // Assert
      expect(result, isA<List<WalletTransaction>>());
      expect(result.length, 2);
      expect(result[0].amount, 100.0);
      verify(mockDio.get(any)).called(1);
    });
  });
}
