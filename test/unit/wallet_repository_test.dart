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
          data: {'data': mockResponse},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/wallet'),
        ),
      );

      // Act
      final result = await repository.getWallet();

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

      when(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).thenAnswer(
        (_) async => Response(
          data: {'data': mockResponse},
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
      verify(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).called(1);
    });

    test('getWallet should parse legacy wallet key', () async {
      final mockResponse = {
        'id': 'wallet-2',
        'user_id': 'user-2',
        'balance': 250.0,
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

      final result = await repository.getWallet();
      expect(result.balance, 250.0);
      expect(result.userId, 'user-2');
    });

    test('requestWithdrawal should return withdraw request payload', () async {
      final mockRequest = {
        'id': 'wr-1',
        'user_id': 'user-1',
        'wallet_id': 'wallet-1',
        'amount': 50.0,
        'currency': 'SAR',
        'status': 'pending',
        'created_at': '2024-01-01T00:00:00Z',
      };

      when(mockDio.post(any, data: anyNamed('data'))).thenAnswer(
        (_) async => Response(
          data: {'data': mockRequest},
          statusCode: 201,
          requestOptions: RequestOptions(path: '/wallet/withdraw'),
        ),
      );

      final result = await repository.requestWithdrawal(amount: 50);
      expect(result.id, 'wr-1');
      expect(result.amount, 50.0);
      expect(result.status, 'pending');
    });

    test('getWithdrawRequests should map list correctly', () async {
      final mockResponse = [
        {
          'id': 'wr-2',
          'user_id': 'user-1',
          'wallet_id': 'wallet-1',
          'amount': 75.0,
          'currency': 'SAR',
          'status': 'approved',
          'created_at': '2024-01-02T00:00:00Z',
        },
      ];

      when(
        mockDio.get(any, queryParameters: anyNamed('queryParameters')),
      ).thenAnswer(
        (_) async => Response(
          data: {'data': mockResponse},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/wallet/withdrawals'),
        ),
      );

      final result = await repository.getWithdrawRequests();
      expect(result.length, 1);
      expect(result.first.localizedStatus, 'مقبول');
    });
  });
}
